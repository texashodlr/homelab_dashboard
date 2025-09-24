# Toy Cluster
This page describes a 'toy' cluster model using 8192 AMD MI325X GPUs.

1. [Supermicro Liquid Cooled Server](https://www.supermicro.com/en/products/system/gpu/4u/as%20-4126gs-nmr-lcc)
    1. Up to 8 GPUs (assuming thusly for our design)
    2. Each GPU has a 400Gbps NIC so each server therefor has 8 x 400Gbps NICs.
    3. Per [slide presentation](https://www.youtube.com/watch?v=JYEBHW8EOzY) we can see racks with 8 servers.
    4. We say that a cluster has 8192 GPUs inside of 1024 Servers inside of 128 Server Racks (at least not assuming additional networking/admin racks)

2. [AMD MI325X Accelerator](https://www.amd.com/content/dam/amd/en/documents/instinct-tech-docs/product-briefs/instinct-mi325x-datasheet.pdf)

3. General Topology
   1. 64 GPUs per rack ~ 64 x 400Gbps = Rack B/W of 25.6 Tbps
   2. 2xToRs per Rack; could assume Arista [7060DX5-64S](https://www.arista.com/assets/data/pdf/Datasheets/7060X5-Datasheet.pdf) 64 x 400GbE QSFP-DD Ports
   3. Each ToR would support 32 400GbE down-links to rack's 8 Servers and 32 400GbE up-links to spines. We split GPU0-3 to ToR-A and GPU4-7 ToR-B. Enables 1:1 non-blocking leaf to spine.
   4. 128 Racks --> 2 ToRs per Rack, 256 ToRs (Leaves)
   5. We leave 32+32 ports free per Rack ToRs so 32 Spines, each spine needs >256 Ports @ 400GbE down to leaves.
   6. Can meet port density requirements with Arista [7800R3 Series](https://www.arista.com/en/products/7800r3-series) targeting 1:1 non-blocking. Each spine gets 256 Ports of 400GbE to every leaf.
   7. Ultimately Two-tier Clos design

4. Misc. Information
   1. Equal-Cost Multi-Path (ECMP): Routing method that allows traffic to be distribtued across multiple parallel paths of equal cost and therefore across our 32 spines which are weighted __equally__. (Load balancing w/out link agg.) (Multiple next hops have the same cost)
   2. Oversubscription Ratio: Ratio of total server-facing bandwidth (downlinks) to total uplink bandwidth. A 1:1 non-blocking fabric (what I propose) means every leaf's downlink BW is matched by uplinks. Increasing ratio (2/4:1) reduces cost and throughput.
   3. RDMA over Converged Ethernet v2 (RoCEv2): Transport protocol for low-latency, kernel-bypass communications over ethernet basically the backbone network protocol for GPU<>GPU.
   4. Priority Flow Control (PFC): Ethernet flow control mechanism that pauses traffic on a per-priority basis rather than per-link, used in RoCE fabrics to make them lossless for RDMA traffic while allow best-effort traffic to drop if congested.
   5. Explicit Congestion Notification (ECN): Congestion signaling method where switches mark packets instead of dropping them. With DCQCN, ECN Feedback allows endpoints to slow down before packet loss occurs.
   6. Data Center Quantized Congestion Notification (DCQCN): Congestion control algo for RoCEv, interprets ECN marks and adjusts RDMA traffic rates dynamically to prevent congestion collapse in lossless fabrics.
   7. Bisection Bandwidth: Total BW available across the middle of the network when we divide it into two equal halves. Heavy bisection bandwidth is make/break for our cluster which features the All<>All.
   8. Pod/Super/Superspine: With the current cluster sizing, 8192 GPUs/1024 Nodes/32 Spines can be considered a single pod for us to expand to say, pow(2,16) GPUs which could be 8 clusters with cluster-interconnect.
   9. Underlay: Physical IP network built with the routed links between leaves and spines, foundation upon which overlays (logical/virtual) are built.
   10. Overlay: Logical network ontop of the underlay with virtual wiring scheme carried inside the physical IP network.
   11. Virtual eXetensible LAN (VXLAN): Encapsulation protocol that wraps ethernet frames inside UDP packets, 'virtual L2 networks' for spanning racks/locations.
   12. BGP: Assuming each leaf gets its own ASN(umber), spines share the ASN such that each leaf<>spine is eBGP ASN:RACK so 128 Racks? 128+1 ASNs

5. [RDMA Stages](https://www.youtube.com/watch?v=6t041Lr5FCY) and [AMD Cluster Networking](https://instinct.docs.amd.com/projects/gpu-cluster-networking/en/latest/index.html)
    1. Hosts init context and register memory regions
    2. Establish connection
    3. Use Send/Receive model to exchange memory region keys between peers
    4. Post read/write operations
    5. Disconnect

6. Discovered the AMD cluster [reference design](https://instinct.docs.amd.com/projects/gpu-cluster-networking/en/latest/_static/cluster/1024-8192-gpu-reference-cluster-design.pdf) for this!

7. Notes from AMD's [GPU Cluster Networking Documentation](https://instinct.docs.amd.com/projects/gpu-cluster-networking/en/latest/index.html)
    1. ROCm enables adding GPU pointers to MPI calls alongside ROCm-aware MPI Libraries for intra&inter-node GPU<>GPU.
    2. AMD kernel driver exposes RDMA access through _PeerDirect_ interfaces (similar to Nvidia's _GPUDirect_) enabling NICs to r/w RDMA-capable GPU device memory for DMA xfer GPU<>NIC.
    3. Unified Communication Framework (UCX, similar to Nvidia's NCCL), standard for RoCEv2 network interconnect, Open MPI leverages UCX internally.
    4. UCX and Open MPI have compile options to enable ROCm support (directions...)
    5. Collective operations on GPU buffers are best handled through the Unified Collective Communication (UCC) library component in Open MPI (which naturally must be configured and compiled) (directions...)
    6. [Article](https://instinct.docs.amd.com/projects/amdgpu-docs/en/latest/system-optimization/mi300x.html) on optimizing MI300X system bios/os