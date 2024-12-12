#!/bin/sh


IFACE=$1
ip link set ${IFACE} up
ip addr add 10.2.1.2/24 dev ${IFACE}
