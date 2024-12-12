SELF=$(eval "echo \$HOST${SELF_ID}")
SELF_SPEED=$(eval "echo \$HOST${SELF_ID}_SPEED")
SELF_DRV=$(eval "echo \$HOST${SELF_ID}_DRV")
SELF_MAC=$(eval "echo \$HOST${SELF_ID}_MAC")
SELF_PCI=$(eval "echo \$HOST${SELF_ID}_PCI")
SELF_IFACE=$(eval "echo \$HOST${SELF_ID}_IFACE")
SELF_MTCP_IFACE=$(eval "echo \$HOST${SELF_ID}_MTCP_IFACE")
SELF_NUMA_CPUMAP=$(eval "echo \$HOST${SELF_ID}_NUMA_CPUMAP")

if [ $SELF_ID == 1 ]; then
	PEER_ID=2
else
	PEER_ID=1
fi

PEER=$(eval "echo \$HOST${PEER_ID}")
PEER_MAC=$(eval "echo \$HOST${PEER_ID}_MAC")

SELF_NODE_MAC=$(eval "echo \$NODE${SELF_ID}_MAC")
PEER_NODE_MAC=$(eval "echo \$NODE${PEER_ID}_MAC")

HOST1_N_NICS=$(echo "${HOST1_PCI}" | wc -w)
HOST2_N_NICS=$(echo "${HOST2_PCI}" | wc -w)

SELF_N_NICS=$(eval "echo \$HOST${SELF_ID}_N_NICS")
