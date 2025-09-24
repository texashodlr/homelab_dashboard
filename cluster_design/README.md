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
