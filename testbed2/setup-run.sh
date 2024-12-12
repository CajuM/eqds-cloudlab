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

sysctl -w vm.swappiness=0
sysctl -w vm.zone_reclaim_mode=0
sysctl -w net.ipv4.route.min_adv_mss=0

iface=$(ip link | grep -B1 "${SELF_MAC}" | head -n1 | grep -Po "^\d: \w+" | awk '{print $2}')
ip link set ${iface} up
ip addr add 10.1.1.${SELF_ID}/24 dev ${iface}

ethtool -K ${iface} tcp-segmentation-offload off
ethtool -K ${iface} generic-segmentation-offload off

ethtool -K ${iface} large-receive-offload off
ethtool -K ${iface} generic-receive-offload off
