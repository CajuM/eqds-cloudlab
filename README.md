# SlimTCP paper benchmark suite

This is the benchmark suite for the paper "SlimTCP: It’s fast, but not because it’s slim".

The purpose of these benchmarks is to measure the goodput and scalability of SlimTCP against other TCP/IP stacks on a reliable in-order channel.

The source code for SlimTCP can be found here: https://github.com/cs-pub-ro/lib-ndpip

## Prerequisites

Two, preferably physical, experiment nodes, each having:
  * At least two cores
  * A decent NIC, >= 25Gbps, supported by DPDK versions: 23.11(SlimTCP), 21.11(F-Stack), 18.05(mTCP)
  * A Linux distribution
  * The kernel set-up with:
    * Huge pages enabled and allocated
    * The second core(1, not 0) set-up for use with DPDK(tick-less mode)
    * The following kernel cmdline should be sufficient: `isolcpus=1 nohz_full=1 rcu_nocbs=1 amd_iommu=on iommu=pt default_hugepagesz=1G hugepagesz=1G hugepages=8 processor.max_cstate=0 rcu_nocb_poll audit=0`
  * The Nix package manager, installed and configured according to `common/nix.conf`
  * SSH access enabled
  * For software requirements see: `setup-host.sh`, it should work on Ubuntu

A separate "driver" node from the previous two, from which the experiments will be ran
  * The Nix package manager, installed and configured according to `common/nix.conf`
  * See: https://nixos.org/download/
  * A SSH client installed with the keys of the two experiment nodes' public keys added, prior to running the experiments

The two experiment nodes must be either:
  * Directly connected
  * Or connected through a switching fabric that does not reorder or loose packets

## Preparation

In order to run any experiment, an "env" file must be created which will describe the hardware in use:
  * The `ENV_NAME`, can be any string that is allowed on a Unix filesystem, it is only used for logging
  * `HOST1` is the SSH destination, as seen from the driver node
  * `HOST1_MACHINE` is the `gcc`/`clang` `-march` option, it must be set according to the CPU mircoarchitecture of the experiment node 
    For possible values, see: `common/machines.txt`
  * `HOST1_SPEED` is the NIC bandwith on the experiment node in Gbps
  * `HOST1_DRV` is the Linux driver that will be used by DPDK, see: https://doc.dpdk.org/guides/tools/devbind.html
  * `HOST1_MAC` is the NIC's MAC address
  * `HOST1_IFACE` the NIC name, as seen by Linux
  * `HOST1_MTCP_IFACE` is the NIC device, as seen by mTCP.
    It is `dpdk0` for most NICs, with a notable exception being Mellanox NICs, where it is equal to `HOST1_IFACE`
  * `HOST1_PCI` is the NIC's PCIe BDF
  * `HOST1_HAS_HW_CKSUM` should be set to 1 for most use-cases
  * Same for `HOST2*`
  * For an example, see: `env-cocos-ps225.sh`

To save time and prevent accidental garbage collection, by the Nix package manager, the packages required by the benchmark must be built and cached, prior to the experiments.

To do so, run in the top directory, on the "driver" node: `nix develop -c "./cache.sh ${HOST1_MACHINE}"`.

If `HOST2_MACHINE` is different from `HOST1_MACHINE`, then you must also run: `nix develop -c "./cache.sh ${HOST2_MACHINE}"`.

This will create several files in the `${TOP}/.cache` directory pointing to the Nix store. When you are done with the experiment, remember to delete this directory. Otherwise, Nix's garbage collection won't pick-up the built packages.

Note: The `TOP` directory is **this** directory where **this file** is found.

Note: This is a CPU consuming operation, you might wish to run it on a machine with many cores.

Note: Accidental deletion of the `.cache` directory may result in the loss of the built packages... **Don't delete it unless you're done with it!!!**

Note: This repo contains submodules. Thus, cloning it with `git clone --recurse` is recommended. 

In order to run mTCP on non-Mellanox NICs, the driver in `pkgs/dpdk-iface` must be built and placed in the `testbed1/` directory.

It can be built like so on Ubuntu: `make -C /usr/lib/modules/$(uname -r)/build M=pkgs/dpdk-iface EXTRA_CFLAGS= modules`. For NixOS, this repo contains an existing package in: `pkgs/dpdk-iface/kmod.nix`.

Note: The kernel modules must be built for the experiment nodes' running kernel.
Note: As a limitation of this benchmark, both experiment nodes must run the same kernel.

## Running the experiments

In order to run the full suite, run: `nix develop -c "./exp.sh you-env-file.sh"`

This repository contains two experiments:
* `exp1.sh` will run a goodput test for a number of MSSs on a single TCP connection
* `exp2.sh` will run a goodput test at a fixed MSS of 1460B for a number of parallel TCP connections

Two testbeds are also provied:
* testbed1 is for DPDK based TCP stacks
* testbed2 is for Linux's TCP stack

For examples, see: `exp.sh`.

The experiment logs will be placed in `${TOP}/out/${ENV_NAME}-${testbed_tx}_${testbed_rx}-exp{1,2}/logs`

Note: Running the experiments **will reboot** the two experiment machines. **Make sure you don't need them!!!** That being said, not passing the `--reboot` option may result in unpredictable execution environments.

## Generating plots and tables

To generate the plots and tables for exp1, run: `nix develop -c "./exp1-diagrams.py out/${ENV_NAME}-${testbed_tx}_${testbed_rx}-exp1/logs"`.
Complete `ENV_NAME`, `testbed_tx` and `testbed_rx` as needed. `testbed_{tx,rx}` are one of "testbed1" or "testbed2".

For the purpose of the paper, only testbed1 was used. Linux was skipped due to its low performance.

The plots and tables for exp2 are generated using `exp2-diagrams.py` , it is invoked in the same way as `exp1-diagrams.py`

## Experiment methodology

* Three TCP/IP stacks were benchmarked: SlimTCP, mTCP and F-Stack
* Four counting Linux
* One benchmark application was built for each stack, they can be found in `pkgs/*-perf`
* The RX/HOST2 node was assigned the `10.1.1.2` IPv4 address, while the TX/HOST1 was assigned the `10.1.1.1` IPv4 address
* The RX application listened on the `4112` port
* The applications were ran with unbuffered STDIO(`stdbuf -o0`)
* The applications used stack specific polling and the `write` and `read` POSIX APIs for data transfer
* The applications output the pps, bps and number of connections, every second
* Each sender/receiver pair runs for 20 seconds, the results are averaged 
* The applications poll and send data on HOST1 and poll and receive data on HOST2
* The applications have a configurable MSS and number of parallel connections
* The TCP/IP stacks and benchmark applications were built using the same toolchain, based on gcc-9, with the `-march=${machine}` and `-O3` options set
* The TCP/IP stacks were built using different DPDK versions, as documented above
* The TCP/IP stacks were patched to support passing the MSS through the command-line
* The TCP/IP stacks were patched to only use two cores and not use LRO/TSO
  * This was considered necessary so that the available bandwidth would not be saturated at high MSSs, making performance differences more visible
* Software checksum verification and calculation was disabled, in the corner case it was used
* Hardware checksum verification and calculation was enabled

## Results

Evaluation was done on top of a bare-metal set-up with two hosts each with 10 cores and 32GiB of RAM, the CPU model was Intel(R) Xeon(R) CPU E5-2670 v2. The hosts were connected through a switch. The installed NICs were Broadcom StingRay PS225, these allowed for a total bandwidth of up to 25Gb/s and up to 68Mpps per port. In the testbed only one port was used as the packet rate was bound by the CPU rather than the NIC.

The experiment outputs, as found in the paper, are available in the `artifacts` folder.

### Mean goodput(bit/s) by segment size

| tx      | rx      | MSS 64B | MSS 256B | MSS 512B | MSS 1460B |
|---------|---------|---------|----------|----------|-----------|
| SlimTCP | SlimTCP | 1.9G    | 6.8G     | 13.0G    | **23.7G** |
| mTCP    | SlimTCP | 2.1G    | 8.1G     | 13.8G    | 16.5G     |
| F-stack | SlimTCP | 410.6M  | 5.2G     | 9.2G     | 15.7G     |
| mTCP    | mTCP    | 1.3G    | 4.4G     | 8.7G     | 12.4G     |
| F-Stack | F-Stack | 670.5M  | 2.1G     | 2.7G     | 3.2G      |
| mTCP    | F-stack | 668.2M  | 1.8G     | 2.3G     | 3.0G      |
| F-stack | mTCP    | 123.4M  | 576.1M   | 8.0G     | 776.8M    |
| SlimTCP | mTCP    | 336.2K  | 1.7M     | 7.3G     | 1.5M      |
| SlimTCP | F-Stack | 675.9M  | 1.7G     | 2.3G     | 190.7K    |

## Mean total goodput(bit/s) by number of connections at 1460B MSS

|tx       | rx      | 1 conn | 1024 conn | 2048 conn | 4096 conn |
|---------|---------|--------|-----------|-----------|-----------|
| SlimTCP | SlimTCP | 23.7G  | 23.7G     | 23.7G     | **23.6G** |
| mTCP 	  | SlimTCP | 16.6G  | 20.3G     | 19.7G     | 19.1G     |
| mTCP    | mTCP    | 12.3G  | 16.0G     | 16.0G     | 15.2G     |
| F-Stack | SlimTCP | 15.5G  | 7.4G      | 5.1G      | 3.3G      |
| SlimTCP | mTCP    | 1.7M   | 968.3M    | 1.3G      | 1.3G      |
| F-Stack | mTCP    | 2.4G   | 12.3G     | 9.7G      | 0.0       |
| F-Stack | F-Stack | 3.2G   | 2.4G      | 1.4G      | 0.0       |
| mTCP    | F-Stack | 3.0G   | 2.5G      | 1.4G      | 0.0       |
| SlimTCP | F-Stack | 193.3K | 267.7M    | 0.0       | 0.0       |

Note: The SlimTCP receiver coalesces ACKs on each burst. Therefore, the sender receives a performance boost, when coupled with it. However, this performance boost disappears once packets, belonging to different sockets, are found in one burst.

Note: Low values(< 2M/connection) with a SlimTCP sender are caused by SlimTCP's lack of proper retransmission. In this case, it means that the receiver looses data packets, possibly in the NIC's RX ring. Or, the sender looses ACKs. But, judging by the scalability graph, the most likely candidate is receiver loss.

## Referencing
```
@misc{caju2026slimtcpitsfastits,
      title={SlimTCP: It's fast, but not because it's slim}, 
      author={Mihai Drosi Caju and Costin Raiciu},
      year={2026},
      eprint={2608.25834},
      archivePrefix={arXiv},
      primaryClass={cs.NI},
      url={https://arxiv.org/abs/2608.25834}, 
}
```
