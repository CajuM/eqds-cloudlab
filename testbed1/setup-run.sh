#!/usr/bin/env bash

set -ex

TOP=$(dirname $(dirname $(readlink -f $0)))
SELF_ID=$1
env=$2

. "${TOP}/${env}"
. "${TOP}/common/env-tail.sh"
. /tmp/devshell

if [[ ${SELF_N_NICS} -gt 1 ]]; then
	exit 1
fi

# Set-up general
modprobe ${SELF_DRV}

pci=$(echo "${SELF_PCI}" | sed 's/^0000://g' | sed 's/\.[0-9]*$//g')
pcis=$(lspci | grep -Po "^${pci}\.\d+" | xargs echo)

for pci in ${pcis}; do
        if [ "${SELF_DRV}" == "mlx5_core" ]; then
                setpci -s ${pci} 68.w
                setpci -s ${pci} 68.w=3BCD

                mlxconfig -d ${pci} set CQE_COMPRESSION=1
        fi

        dpdk-devbind.py --force -b ${SELF_DRV} ${pci}
done

sysctl -w vm.swappiness=0
sysctl -w vm.zone_reclaim_mode=0

echo -1 > /proc/sys/kernel/sched_rt_runtime_us

if [ -n "${SELF_NUMA_CPUMAP}" ]; then
	IRQBALANCE_BANNED_CPUS=${SELF_NUMA_CPUMAP} irqbalance --oneshot
fi

systemctl stop irqbalance.service || true

if [ -z "$(lsmod | grep dpdk_iface)" ]; then insmod "${TOP}/testbed1/dpdk_iface.ko"; fi
dpdk_iface_main || true
ip addr add 10.1.1.${SELF_ID}/24 dev ${SELF_MTCP_IFACE}
ip link set ${SELF_MTCP_IFACE} down
ls /sys/devices/system/cpu/cpu*/online | grep -vP "cpu([0-9]|1[0-5])/" | xargs -IIOTA sh -c 'echo 0 >IOTA'

if [[ -n "${SELF_IFACE}" && -z "$(echo $SELF_IFACE | grep -P dpdk\d+)" ]]; then
	ethtool -A ${SELF_IFACE} rx off tx off
fi

# Set-up mTCP
mkdir -p config
cat "${TOP}/testbed1/arp.conf.in" | NEIGH_IP="10.1.1.${PEER_ID}" NEIGH_MAC="${PEER_MAC}" envsubst >config/arp.conf
cat "${TOP}/testbed1/perf.conf.in" | IFACE="${SELF_MTCP_IFACE}" envsubst >perf.conf
