#!/bin/sh

set -ex

TOP=$(dirname $(dirname $(readlink -f $0)))

. /tmp/devshell

exec dpdk-testpmd -l 0,1,2 --proc-type=primary --no-pci --vdev net_vhost0,iface=/tmp/dpdk1,client=0 --vdev net_vhost1,iface=/tmp/dpdk2,client=0 -- --nb-cores=2 --cmdline=${TOP}/testbed1/testpmd-cmd.txt &>/tmp/testpmd.log
