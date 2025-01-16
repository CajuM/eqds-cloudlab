function setup_exp {
	rm -rf "${LOGS}"
	mkdir -p "${LOGS}"

	if [ "${reboot}" == "1" ]; then
		reboot="--reboot"
	fi

	${TOP}/common/setup-exp.sh --env ${env} --testbed-tx ${testbed_tx} --testbed-rx ${testbed_rx} ${reboot}
}

function mtcp_tcp_tx {
	rx=$1
	mss=$2
	connections=$3
	log=$4

	${SSH1} "MTCP_MSS=${mss} MTCP_CONFIG=perf.conf stdbuf -o0 mtcp-perf --connect-ip 10.1.1.2 --connect-port 4112 --connections ${connections}" &>"${log}" &
	pid=$!

	echo $pid
}

function mtcp_tcp_rx {
	tx=$1
	mss=$2
	connections=$3
	log=$4

	${SSH2} "MTCP_MSS=${mss} MTCP_CONFIG=perf.conf stdbuf -o0 mtcp-perf --bind-port 4112 --listen" &>"${log}" &
	pid=$!

	echo $pid
}

function f_stack_tcp_tx {
	rx=$1
	mss=$2
	connections=$3
	log=$4

	cat "${TOP}/common/f-stack-config.ini.in" | NO_HW_CKSUM=$(((NODE1_HAS_HW_CKSUM + 1) % 2)) MSS=${mss} HOST_PCI=${NODE1_PCI} IP_ADDR="10.1.1.1" envsubst | ${SSH1} 'cat >/tmp/f-stack-config.ini'
	${SSH1} "stdbuf -o0 f-stack-perf --conf /tmp/f-stack-config.ini --proc-type=primary --proc-id=0 -- --arp 10.1.1.2:${NODE2_MAC} --connect-ip 10.1.1.2 --connect-port 4112 --connections ${connections} --mss ${mss} --tcp 2>&1" &>"${log}" &
	pid=$!

	echo $pid
}

function f_stack_tcp_rx {
	tx=$1
	mss=$2
	connections=$3
	log=$4

	cat "${TOP}/common/f-stack-config.ini.in" | NO_HW_CKSUM=$(((NODE2_HAS_HW_CKSUM + 1) % 2)) MSS=${mss} HOST_PCI=${NODE2_PCI} IP_ADDR="10.1.1.2" envsubst | ${SSH2} 'cat >/tmp/f-stack-config.ini'
	${SSH2} "stdbuf -o0 f-stack-perf --conf /tmp/f-stack-config.ini --proc-type=primary --proc-id=0 -- --arp 10.1.1.1:${NODE1_MAC} --bind-port 4112 --listen --mss ${mss} --tcp 2>&1" &>"${log}" &
	pid=$!

	echo $pid
}

function ndpip_tcp_tx {
	rx=$1
	mss=$2
	connections=$3
	log=$4

	${SSH1} "stdbuf -o0 eqds-tcp-perf --no-telemetry -a ${NODE1_PCI} -l 0,1 --proc-type=primary --socket-mem=2048 -- --iface 0 --burst 32 --arp 10.1.1.2:${NODE2_MAC} --bind-eth ${NODE1_MAC} --bind-ip 10.1.1.1 --connections ${connections} --connect-ip 10.1.1.2 --connect-port 4112 --mss ${mss} --tcp" &>"${log}" &
	pid=$!

	echo $pid
}

function ndpip_tcp_rx {
	rx=$1
	mss=$2
	connections=$3
	log=$4

	${SSH2} "stdbuf -o0 eqds-tcp-perf --no-telemetry -a ${NODE2_PCI} -l 0,1 --proc-type=primary --socket-mem=2048 -- --iface 0 --burst 32 --arp 10.1.1.1:${NODE1_MAC} --bind-eth ${NODE2_MAC} --bind-ip 10.1.1.2 --bind-port 4112 --listen --mss ${mss} --tcp --win-scale 3" &>"${log}" &
	pid=$!

	echo $pid
}

function linux_tcp_tx {
	rx=$1
	mss=$2
	connections=$3
	log=$4

	${SSH1} "stdbuf -o0 linux-perf --iface ${NODE1_IFACE} --connect-ip 10.1.1.2 --connect-port 4112 --connections ${connections} --mss ${mss}" &>"${log}" &
	pid=$!

	echo $pid
}

function linux_tcp_rx {
	tx=$1
	mss=$2
	connections=$3
	log=$4

	${SSH2} "stdbuf -o0 linux-perf --iface ${NODE2_IFACE} --bind-port 4112 --listen --mss ${mss}" &>"${log}" &
	pid=$!

	echo $pid
}

function do_exp {
	proto=$1
	mss=$2
	connections=$3

	if [ "${proto}" == "tcp" ]; then
		payload_inc=20
	fi

	for tx in ${stacks_tx}; do
		for rx in ${stacks_rx}; do
			for _ in $(seq 1 5); do
				host2_log="${LOGS}/h2.${tx}-${rx}.${proto}.${mss}.${connections}.log"
				host2_pid=$(eval "${rx}_${proto}_rx $tx $mss $connections '${host2_log}'")
				sleep 20
				host1_log="${LOGS}/h1.${tx}-${rx}.${proto}.${mss}.${connections}.log"
				host1_pid=$(eval "${tx}_${proto}_tx $rx $mss $connections '${host1_log}'")

				sleep 20

				${SSH2} "pkill -9 mtcp-perf; pkill -9 eqds-tcp-perf; pkill -9 f-stack-perf; pkill -9 linux-perf; true"
				${SSH1} "pkill -9 mtcp-perf; pkill -9 eqds-tcp-perf; pkill -9 f-stack-perf; pkill -9 linux-perf; true"

				wait $host1_pid || true
				wait $host2_pid || true

				if grep '^pps=' "${host2_log}" | grep -v '^pps=0;'; then
					break
				fi
			done
		done
	done
}

function kill_exp {
	if [ "${reboot}" == "1" ]; then
		reboot="--reboot"
	fi

	${TOP}/common/kill-exp.sh --env ${env} --testbed-tx ${testbed_tx} --testbed-rx ${testbed_rx} ${reboot}
}
