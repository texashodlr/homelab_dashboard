# Home Lab Dashboard
Application which lets the user know the general health status of their homelab.


## Air-Gapped Requirements

0. Nvidia

0.1. `Configure NVIDIA Drivers and CUDA on your nodes`

0.1.A. _Validate with_: `nvidia-smi -q | grep -E 'Driver Version|CUDA Version'`

0.2. `Install DCGM on your nodes`

0.2.A. _Install GO inside of 0-go.tar_: `rpm -iv *.rpm`

0.2.B. _Install the DCGM rpms inside of 1-nvidia-dcgm.tar_: `rpm -iv *.rpm`

0.2.B.1. _Turn on DCGM_: `sudo systemctl --now enable nvidia-dcgm`

0.2.B.2. _Query the local system_: `dcgmi discovery -l` or with `dcgmi diag -r [1/2/3/4]` or `dcgmi health -s a` or `dcgmi health -c`

0.2.B.3. _Some useful links_: [Dell x DCGM](https://www.dell.com/support/kbdoc/en-hk/000219485/nvidia-dcgm-datacenter-gpu-manager-install) and [Nvidia DCGM Install Docs](https://docs.nvidia.com/datacenter/dcgm/latest/user-guide/getting-started.html#id2)

0.2.C. [_Build DCGM Exporter from source_](https://github.com/NVIDIA/dcgm-exporter):

`unzip 2_dcgm_exporter.zip`

`cd dcgm-exporter`

`make binary`

`sudo make install`

_...wait..._

`dcgm-exporter & curl localhost:9400/metrics`

0.3. _Install Prometheus on the control plane_: 

## Requirements

### Ansible 

0. [Ansible __for RHEL__](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html#installing-distros)

`subscription-manager repos --enable ansible-2.9-for-rhel-8-x86_64-rpms`

`sudo yum install ansible`

1. [Prometheus Node Exporter](https://prometheus-community.github.io/ansible/branch/main/node_exporter_role.html#ansible-collections-prometheus-prometheus-node-exporter-role)

`ansible-galaxy collection install prometheus.prometheus`

__or__

`ansible-galaxy install -r requirements.yml`

2. [Prometheus Nvidia GPU Export](https://prometheus-community.github.io/ansible/branch/main/nvidia_gpu_exporter_role html#ansible-collections-prometheus-prometheus-nvidia-gpu-exporter-role)

### Non-Ansible

#### Prometheus Node Exporter
[Link](https://github.com/prometheus/node_exporter)

#### Nvidia Node-Exporter
[Link](https://github.com/NVIDIA/dcgm-exporter)


##### Ubuntu 24.04 Prep
1. `apt update`
2. `apt install cuda-toolkit`
3. Reboot
4. `export PATH=${PATH}:/usr/local/cuda-13.0/bin`
5. `export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/cuda-13.0/lib64`
6. Navigate to [CUDA-Samples](https://github.com/nvidia/cuda-samples)
7. `git clone https://github.com/nvidia/cuda-samples`

##### Bare-Metal Nvidia NE Build
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

##### Container DCGM-Exporter

`...`