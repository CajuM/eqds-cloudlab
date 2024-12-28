#!/bin/sh

set -ex

exp=exp2

options=$(getopt -l "reboot,mss:,stacks-h1:,stacks-h2:,testbed-h1:,testbed-h2:,env:" -o "sx" -- "$@")
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
		--stacksh1) stacks_h1=$2; shift; shift;;
		--stacks-h2) stacks_h2=$2; shift; shift;;
		--reboot) reboot=1; shift;;
		--testbed-h1) testbed_h1=$2; shift; shift;;
		--testbed-h2) testbed_h2=$2; shift; shift;;
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
