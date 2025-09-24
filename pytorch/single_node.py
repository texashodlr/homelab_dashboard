# This code leverages Pytorch's DDP Series and related file `single_gpu.py`
# https://github.com/pytorch/examples/blob/main/distributed/ddp-tutorial-series/single_gpu.py
# pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cu126
# default run configuration 

import numpy as np
import torch
import torch.nn.functional as F
from torch.utils.data import Dataset, DataLoader
import matplotlib.pyplot as plt
from typing import List, Optional
#from datautils import MyTrainDataset

class MyTrainDataset(Dataset):
    def __init__(self, num_samples: int, feature_dim: int = 20, num_class: int = 10):
        self.X = torch.randn(num_samples, feature_dim)
        self.y = torch.randint(0, num_class, (num_samples,))
    
    def __len__(self):
        return self.X.size(0)
    
    def __getitem__(self, idx):
        return self.X[idx], self.y[idx]

class Trainer:
    def __init__(
        self,
        model: torch.nn.Module,
        train_data: DataLoader,
        optimizer: torch.optim.Optimizer,
        gpu_id: int,
        save_every: int,
        loss_log: Optional[List[float]] = None,
    ) -> None:
        self.gpu_id = gpu_id
        print(f"GPU ID: {self.gpu_id}")
        self.model = model.to(gpu_id)
        self.train_data = train_data
        self.optimizer = optimizer
        self.save_every = save_every
        self.loss_log = loss_log if loss_log is not None else []

    def _run_batch(self, source, targets):
        self.optimizer.zero_grad()
        output = self.model(source)
        loss = F.cross_entropy(output, targets)
        loss.backward()
        self.optimizer.step()
        self.loss_log.append(float(loss.item()))
        #print(f"[GPU{self.gpu_id}] | Loss: {loss} | Source: {type(source)} | Targets: {type(targets)}")
    
    def _run_epoch(self, epoch):
        b_sz = len(next(iter(self.train_data))[0])
        print(f"[GPU{self.gpu_id}] Epoch {epoch} | Batchsize: {b_sz} | Steps: {len(self.train_data)}")
        for source, targets in self.train_data:
            source = source.to(self.gpu_id)
            targets = targets.to(self.gpu_id)
            self._run_batch(source, targets)
    
    def _save_checkpoints(self, epoch):
        ckp = self.model.state_dict()
        PATH = "checkpoint.pt"
        torch.save(ckp, PATH)
        print(f"Epoch {epoch} | Training checkpoint saved at {PATH}")
    
    def train(self, max_epochs: int):
        for epoch in range(max_epochs):
            self._run_epoch(epoch)
            if epoch % self.save_every == 0:
                self._save_checkpoints(epoch)
    
    def loss_plot(self, total_epochs):
        # Plotting the loss per epoch
        print(f"Total Epochs: {total_epochs} | Dimensions of Loss_log: {len(self.loss_log)}")
        plt.figure()
        plt.plot(np.arange(1, len(self.loss_log) + 1), self.loss_log)
        plt.xlabel(f"Epoch /e/ [0..{total_epochs}]")
        plt.ylabel("Loss ")
        plt.title(f"Loss per Epoch")
        plt.grid(True)
        plt.tight_layout()
        plt.savefig("loss_curve.png", dpi=150)
        plt.show()
    
def load_train_objs():
    #rng = np.random.default_rng(63)
    #train_set = rng.standard_normal((2048, 1))
    train_set = MyTrainDataset(2048, feature_dim=20, num_class=10)
    model = torch.nn.Linear(20, 10)
    optimizer = torch.optim.SGD(model.parameters(), lr=1e-3)
    return train_set, model, optimizer
    
def prepare_dataloader(dataset: Dataset, batch_size: int):
    return DataLoader(
        dataset,
        batch_size=batch_size,
        pin_memory=True,
        shuffle=True
    )
    
def main(device, device_loop, total_epochs, save_every, batch_size):
    dataset, model, optimizer = load_train_objs()
    train_data = prepare_dataloader(dataset, batch_size=32)
    if device_loop == True:
        print(torch.cuda.device_count())
        for i in range(torch.cuda.device_count()):
            print(f"Initiating training on GPU #{i}: {torch.cuda.get_device_properties(i).name}...")
            device = int(i)
            trainer = Trainer(model, train_data, optimizer, device, save_every)
            trainer.train(total_epochs)
            trainer.loss_plot(total_epochs)
    else:
        trainer = Trainer(model, train_data, optimizer, device, save_every)
        trainer.train(total_epochs)
        trainer.loss_plot(total_epochs)

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description='simple distributed training job')
    parser.add_argument('total_epochs', type=int, help='Total epochs to train the model')
    parser.add_argument('save_every', type=int, help='How often to save a snapshot')
    parser.add_argument('--batch_size', default=32, type=int, help='Input batch size on each device (default: 32)')
    parser.add_argument('--device_id', default=0, type=int, help='Pick your GPU (default is 0 for single rigs)')
    parser.add_argument('--device_loop', default=False, type=bool, help='Loop through the available GPU devices')
    args = parser.parse_args()
    main(args.device_id, args.device_loop, args.total_epochs, args.save_every, args.batch_size)
