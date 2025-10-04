import os
import sys
import torch
from torch.utils.data import random_split
from torch.distributed import init_process_group, destroy_process_group
from model import GPT, GPTConfig, OptimizerConfig, create_optimizer
from trainer import Trainer, TrainerConfig
from char_dataset import CharDataset, DataConfig
from omegaconf import DictConfig
import hydra

def verify_min_gpu_count(min_gpus: int = 2) -> bool:
    has_gpu = torch.cuda.is_available()
    gpu_count = torch.cuda.device_count()
    return has_gpu and gpu_count >= min_gpus

def ddp_setup():
    """
    Converting the old `torch.accelerator.*` code to `torch.cuda.*`
    """
    if not torch.cuda.is_available():
        raise RuntimeError("CUDA not available and ddp_setup() expects onboard GPUs...")
    local_rank = int(os.environ["LOCAL_RANK"])      # Per node rank, 0...(nproc_per_node-1)
    rank       = int(os.environ.get("RANK", 0))         # Global rank/GPU ID
    world_size = int(os.environ.get("WORLD_SIZE",1))

    # Setting the backend comm suite to NCCL for NVIDIA
    backend = "nccl"

    # Pinning the process to its GPU
    torch.cuda.set_device(local_rank)
    device = torch.device(f"CUDA:{local_rank}")

    # Init process group
    init_process_group(backend=backend, rank=rank, world_size=world_size)

def get_train_objs(gpt_cfg: GPTConfig, opt_cfg: OptimizerConfig, data_cfg: DataConfig):
    dataset = CharDataset(data_cfg)
    train_len = int(len(dataset) * data_cfg.train_split)
    train_set, test_set = random_split(dataset, [train_len, len(dataset) - train_len])

    gpt_cfg.vocab_size = dataset.vocab_size
    gpt_cfg.block_size = dataset.block_size
    model = GPT(gpt_cfg)
    optimizer = create_optimizer(model, opt_cfg)
    
    return model, optimizer, train_set, test_set

@hydra.main(version_base=None, config_path=".", config_name="gpt2_train_cfg")
def main(cfg: DictConfig):
    ddp_setup()

    gpt_cfg = GPTConfig(**cfg['gpt_config'])
    opt_cfg = OptimizerConfig(**cfg['optimizer_config'])
    data_cfg = DataConfig(**cfg['data_config'])
    trainer_cfg = TrainerConfig(**cfg['trainer_config'])

    model, optimizer, train_data, test_data = get_train_objs(gpt_cfg, opt_cfg, data_cfg)
    trainer = Trainer(trainer_cfg, model, optimizer, train_data, test_data)
    trainer.train()

    destroy_process_group()

if __name__ == "__main__":
    _min_gpu_count = 2
    if not verify_min_gpu_count(min_gpus=_min_gpu_count):
        print(f"Unable to locate sufficient {_min_gpu_count} gpus to run this example. Exiting.")
        sys.exit()
    main()