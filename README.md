# Home Lab Dashboard
Application which lets the user know the general health status of their homelab.


## Requirements

### Prometheus Node Exporter
[Link](https://github.com/prometheus/node_exporter)

### Nvidia Node-Exporter
[Link](https://github.com/NVIDIA/dcgm-exporter)


#### Ubuntu 24.04 Prep
1. `apt update`
2. `apt install cuda-toolkit`
3. Reboot
4. `export PATH=${PATH}:/usr/local/cuda-13.0/bin`
5. `export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/cuda-13.0/lib64`
6. Navigate to [CUDA-Samples](https://github.com/nvidia/cuda-samples)
7. `git clone https://github.com/nvidia/cuda-samples`
8. 

#### Bare-Metal Nvidia NE Build
1. Install [Golang](https://go.dev/dl/)
`wget https://go.dev/dl/go1.25.1.linux-amd64.tar.gz`

`sudo tar -C /usr/local/ -xzf go1.25.1.linux-amd64.tar.gz`

`rm go1.25.1.linux-amd64.tar.gz`

`mkdir -p ~/go/{bin,src,pkg}`

`export GOROOT=/usr/local/go`

`export GOPATH=$HOME/go`

`export PATH=$PATH:$GOROOT/bin:$GOPATH/bin`

`source ~/.bashrc`

`go version`

_Should see something like_: `go version go1.22.2 linux/amd64`

2. Install [Nvidia's DCGM](https://github.com/NVIDIA/DCGM) and [Guide](https://docs.nvidia.com/datacenter/dcgm/latest/user-guide/getting-started.html)

__Verification of CUDA and Drivers__

`nvidia-smi -q | grep -E 'Driver Version|CUDA Version'`

__Installation of Dependencies__

`sudo dpkg --list datacenter-gpu-manager &> /dev/null && sudo apt purge --yes datacenter-gpu-manager`

`sudo dpkg --list datacenter-gpu-manager-config &> /dev/null && sudo apt purge --yes datacenter-gpu-manager-config`

`wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb`

`sudo dpkg -i cuda-keyring_1.1-1_all.deb`

`sudo add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/ /"`

`sudo apt-get update`

`sudo apt-get install -y datacenter-gpu-manager`

`CUDA_VERSION=<MAJOR VERSION OF CUDA ~ 13.0>`

`sudo apt-get install --yes --install-recommends datacenter-gpu-manager-4-cuda${CUDA_VERSION}`

_Optional_
`sudo apt install --yes datacenter-gpu-manager-4-multinode-cuda${CUDA_VERSION}`
`sudo apt install --yes datacenter-gpu-manager-4-dev`

__Post Installation__
`sudo systemctl --now enable nvidia-dcgm`
`dcgmi discovery -l`
__At this point DCGM is installed and functional__
3. Install [Nvidia's DCGM node_exporter](https://github.com/NVIDIA/dcgm-exporter)
__Installation__
`git clone https://github.com/NVIDIA/dcgm-exporter.git`
`cd dcgm-exporter`
`make binary`
`sudo make install`
`...`
`dcgm-exporter & curl localhost:9400/metrics`

#### Container DCGM-Exporter