#!/bin/sh

set -ex

TOP=$(dirname $(dirname $(readlink -f $0)))

options=$(getopt -l "reboot,testbed-h1:,testbed-h2:,env:" -o "sx" -- "$@")
eval set -- "$options"

reboot=0

while true; do
	case "$1" in
		--reboot) reboot=1; shift;;
		--testbed-h1) testbed_h1=$2; shift; shift;;
		--testbed-h2) testbed_h2=$2; shift; shift;;
		--env) env=$2; shift; shift;;
		--) shift; break;;
	esac
done

. "${TOP}/common/head.sh"

for host in $(seq 1 ${N_HOSTS}); do
	host=$(eval "echo \$HOST${host}")

	cat ${TOP}/common/kill-exp.in | ssh ${host}
	if [ "${reboot}" == "1" ]; then
		ssh ${host} reboot || true
	fi
done
