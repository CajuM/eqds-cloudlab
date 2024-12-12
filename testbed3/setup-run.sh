#!/bin/sh

set -ex

TOP=$(dirname $(dirname $(readlink -f $0)))

SELF_ID=$1
env=$2

cd ${TOP}/testbed3

. "${TOP}/${env}"
. "${TOP}/common/env-tail.sh"

sysctl -w vm.swappiness=0
sysctl -w vm.zone_reclaim_mode=0

echo -1 > /proc/sys/kernel/sched_rt_runtime_us

if [ -n "${SELF_NUMA_CPUMAP}" ]; then
	IRQBALANCE_BANNED_CPUS=${SELF_NUMA_CPUMAP} irqbalance --oneshot
fi

systemctl stop irqbalance.service || true

modprobe ${SELF_DRV}

pcis=""
for pci in ${SELF_PCI}; do
        pci=$(echo "${pci}" | sed 's/^0000://g' | sed 's/\.[0-9]*$//g')
        pcis_tmp=$(lspci | grep -Po "^${pci}\.\d+" | xargs echo)
        pcis="${pcis} ${pcis_tmp}"
done

for pci in ${pcis}; do
	if [ "${SELF_DRV}" == "mlx5_core" ]; then
		setpci -s ${pci} 68.w
		setpci -s ${pci} 68.w=3BCD

		mlxconfig -d ${pci} set CQE_COMPRESSION=1
	fi

	dpdk-devbind.py --force -b ${SELF_DRV} ${pci}
done

./tmux.sh self $1 $2
