# Toy Cluster
This page describes a 'toy' cluster model using 8192 AMD MI325X GPUs.

1. [Supermicro Liquid Cooled Server](https://www.supermicro.com/en/products/system/gpu/4u/as%20-4126gs-nmr-lcc)
    1. Up to 8 GPUs (assuming thusly for our design)
    2. Each GPU has a 400Gbps NIC so each server therefor has 8 x 400Gbps NICs.
    3. Per [slide presentation](https://www.youtube.com/watch?v=JYEBHW8EOzY) we can see racks with 8 servers.
    4. We say that a cluster has 8192 GPUs inside of 1024 Servers inside of 128 Server Racks (at least not assuming additional networking/admin racks)

2. [AMD MI325X Accelerator](https://www.amd.com/content/dam/amd/en/documents/instinct-tech-docs/product-briefs/instinct-mi325x-datasheet.pdf)