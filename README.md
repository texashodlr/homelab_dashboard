# Home Lab Dashboard
Application which lets the user know the general health status of their homelab.


## Requirements

### Prometheus Node Exporter
[Link](https://github.com/prometheus/node_exporter)

### Nvidia Node-Exporter
[Link](https://github.com/NVIDIA/dcgm-exporter)


#### Bare-Metal Nvidia NE Build
1. Install Golang
2. Install [Nvidia's DCGM](https://github.com/NVIDIA/DCGM) and [Guide](https://docs.nvidia.com/datacenter/dcgm/latest/user-guide/getting-started.html)
__Installation of Dependencies__
`sudo dpkg --list datacenter-gpu-manager &> /dev/null && sudo apt purge --yes datacenter-gpu-manager`
`sudo dpkg --list datacenter-gpu-manager-config &> /dev/null && sudo apt purge --yes datacenter-gpu-manager-config`
`CUDA_VERSION=<MAJOR VERSION OF CUDA ~ 13.0>`
`sudo apt-get install --yes --install-recommends datacenter-gpu-manager-4-cuda${CUDA_VERSION}`
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