#ifndef _H_FSTACK_PERF_ARP_H_
#define _H_FSTACK_PERF_ARP_H_

#include <sys/socket.h>

int arp_set(struct in_addr addr, struct ether_addr laddr);

#endif
