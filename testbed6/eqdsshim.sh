#!/bin/sh

set -ex

TOP=$(dirname $(dirname $(readlink -f $0)))
SELF_ID=$1
env=$2

. "${TOP}/${env}"
. "${TOP}/common/env-tail.sh"
. /tmp/devshell

BDP=$((64 * ${SELF_SPEED} / 10))

echo "10.1.1.${PEER_ID} ${PEER_MAC}" >/tmp/eqdsshim-arp.txt

if [[ ${SELF_N_NICS} -gt 1 ]]; then
	EXTRA_DPDK_ARGS1="--vdev net_bonding0,mode=0,mac=${SELF_MAC}"
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

exec eqdsshim -l 1,2 ${EXTRA_DPDK_ARGS} --vdev "net_vhost0,iface=/tmp/dpdk${SELF_ID},client=0" --socket-mem 2048 -- -a 10.1.1.${SELF_ID} -n ${NW_PORT} -h ${VM_PORT} -e 12:23:34:45:56:0${SELF_ID} -t /tmp/eqdsshim-arp.txt -m 1500 -b ${SELF_SPEED} -B ${BDP} -f eqdsshim.json &>/tmp/eqdsshim.log
