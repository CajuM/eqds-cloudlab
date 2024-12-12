#!/bin/sh

set -ex

exp=exp2

options=$(getopt -l "reboot,mss:,stacks-tx:,stacks-rx:,testbed-tx:,testbed-rx:,env:" -o "sx" -- "$@")
eval set -- "$options"

tcp_connections_list=
for i in 0 10 11 12; do
	tcp_connections_list="${tcp_connections_list} $((2 ** i))"
done

mss=1460
excludes=""

while true; do
	case "$1" in
		--mss) shift; mss=$1; shift;;
		--stacks-rx) stacks_rx=$2; shift; shift;;
		--stacks-tx) stacks_tx=$2; shift; shift;;
		--reboot) reboot=1; shift;;
		--testbed-rx) testbed_rx=$2; shift; shift;;
		--testbed-tx) testbed_tx=$2; shift; shift;;
		--env) env=$2; shift; shift;;
		--) shift; break;;
	esac
done

TOP=$(dirname $(readlink -f $0))

. "${TOP}/common/head.sh"

setup_exp

set +e

for connections in $(eval "echo $tcp_connections_list"); do
	do_exp "tcp" ${mss} ${connections}
done

kill_exp
