#!/bin/sh

set -ex

TOP=$(dirname $(dirname $(readlink -f $0)))
env=$2

. "${TOP}/${env}"
. "${TOP}/common/env-tail.sh"

cd ${TOP}/testbed1

sysctl -w vm.swappiness=0
sysctl -w vm.zone_reclaim_mode=0

echo -1 > /proc/sys/kernel/sched_rt_runtime_us

if [ -n "${SELF_NUMA_CPUMAP}" ]; then
	IRQBALANCE_BANNED_CPUS=${SELF_NUMA_CPUMAP} irqbalance --oneshot
fi

systemctl stop irqbalance.service || true

./tmux.sh self
