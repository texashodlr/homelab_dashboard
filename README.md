# Home Lab Dashboard
Application which lets the user know the general health status of their homelab.


## Air-Gapped Requirements

1. Nvidia
    1. _Configure NVIDIA Drivers and CUDA on your nodes_
        1. _Validate with_: `nvidia-smi -q | grep -E 'Driver Version|CUDA Version'`
    2. _Install DCGM on your nodes_
        1. _Install GO inside of 0-go.tar_: `rpm -iv *.rpm`
        2. _Install the DCGM rpms inside of 1-nvidia-dcgm.tar_: `rpm -iv *.rpm`
            1. _Turn on DCGM_: `sudo systemctl --now enable nvidia-dcgm`
            2. _Query the local system_: `dcgmi discovery -l` or with `dcgmi diag -r [1/2/3/4]` or `dcgmi health -s a` or `dcgmi health -c`
            3. _Some useful links_: [Dell x DCGM](https://www.dell.com/support/kbdoc/en-hk/000219485/nvidia-dcgm-datacenter-gpu-manager-install) and [Nvidia DCGM Install Docs](https://docs.nvidia.com/datacenter/dcgm/latest/user-guide/getting-started.html#id2)
        3. [_Build DCGM Exporter from source_](https://github.com/NVIDIA/dcgm-exporter):
        ```
        unzip 2_dcgm_exporter.zip
        cd dcgm-exporter
        make binary
        sudo make install
        _...wait..._
        dcgm-exporter & curl localhost:9400/metrics
        ```
    3. _Install Prometheus on the control plane and nodes_: 
        1. _Prometheus tarball_: `prometheus-3.5.0.linux-amd64.tar.gz`
        2. _Prometheus playbook_: `./ansible/playbooks/prometheus.yml`
        3. _General run-order_:
            1. _Install the offline collection to the control-plane_: `ansible-galaxy collection install ./collections/ansible_collections/prometheus/prometheus-prometheus-0.27.3.tar.gz`
            2. _Deploy the prometheus node exporters to the downstream nodes_: `ansible-playbook -i inventory.yml playbooks/node_exporter.yml`
            3. _Deploy the DCGM node exporters to the downstream nodes_: `ansible-playbook -i inventory.yml playbooks/dcgm_exporter.yml`
            4. _Deploy the Prometheus server to the control plane_: `ansible-playbook -i inventory.yml playbooks/prometheus.yml`
            5. _Open firewalld ports_: `ansible-playbook -i inventory.yml playbooks/firewalld.yml`
        4. _Verification of control-plane install_:
            ```
            systemctl status prometheus
            ss -lntp | grep 9090
            curl -s http://<control-plane-ip>:9090/-/ready
            ```

## Internet-Connected Requirements

### General Directions

1. _Install the prometheus collection on the control plane node_

	`wget https://github.com/prometheus/prometheus/releases/download/v3.5.0/prometheus-3.5.0.linux-amd64.tar.gz`

	_Building from source_

2. _Deploy node exporter to the nodes_

	`ansible-playbook -i inventory.yml playbooks/node_exporter.yml`

3. _Deploy DCGM exporter to GPU nodes_

	`ansible-playbook -i inventory.yml playbooks/dcgm_exporter.yml`

4. _Deploy prometheus server to control plane_

	`ansible-playbook -i inventory.yml playbooks/prometheus.yml`

5. _Networking config_

	`ansible-playbook -i inventory.yml playbooks/firewalld.yml`

### Ansible 

1. [Ansible __for RHEL__](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html#installing-distros)

	`subscription-manager repos --enable ansible-2.9-for-rhel-8-x86_64-rpms`

	`sudo yum install ansible`

2. [Prometheus Node Exporter](https://prometheus-community.github.io/ansible/branch/main/node_exporter_role.html#ansible-collections-prometheus-prometheus-node-exporter-role)

	`ansible-galaxy collection install prometheus.prometheus`

	__or__

	`ansible-galaxy install -r requirements.yml`

3. [Prometheus Nvidia GPU Export](https://prometheus-community.github.io/ansible/branch/main/nvidia_gpu_exporter_role html#ansible-collections-prometheus-prometheus-nvidia-gpu-exporter-role)

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
