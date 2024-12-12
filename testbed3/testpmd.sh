#!/bin/sh

set -ex

TOP=$(dirname $(dirname $(readlink -f $0)))
SELF_ID=$1
env=$2

. "${TOP}/${env}"
. "${TOP}/testbed3/vars.sh"
. "${TOP}/common/env-tail.sh"
. /tmp/devshell

if [[ ${SELF_N_NICS} -gt 1 ]]; then
	EXTRA_DPDK_ARGS1="--vdev net_bonding0,mode=2,xmit_policy=l34,mac=${SELF_MAC}"
	EXTRA_DPDK_ARGS2=""

	for pci in ${SELF_PCI}; do
		EXTRA_DPDK_ARGS1="${EXTRA_DPDK_ARGS1},member=${pci}"
		EXTRA_DPDK_ARGS2="${EXTRA_DPDK_ARGS2} -a ${pci}"
	done

	EXTRA_DPDK_ARGS="${EXTRA_DPDK_ARGS1}${EXTRA_DPDK_ARGS2}"
	NW_PORT=${SELF_N_NICS}
else
	EXTRA_DPDK_ARGS="-a ${SELF_PCI}"
	NW_PORT=0
fi

VM_PORT=$((NW_PORT + 1))
PORTMASK=$(printf '0x%x' $((3 << NW_PORT)))

cat ${TOP}/testbed3/testpmd-cmd.txt.in | NW_PORT="${NW_PORT}" VM_PORT="${VM_PORT}" envsubst >/tmp/testpmd-cmd.txt

exec dpdk-testpmd -l 0,1,2 --proc-type=primary ${EXTRA_DPDK_ARGS} --vdev "net_vhost0,iface=/tmp/dpdk${SELF_ID},client=0" -- --nb-cores=2 --portmask=${PORTMASK} --eth-peer=${NW_PORT},${PEER_MAC} --eth-peer=${VM_PORT},${SELF_NODE_MAC} --cmdline=/tmp/testpmd-cmd.txt &>/tmp/testpmd.log
