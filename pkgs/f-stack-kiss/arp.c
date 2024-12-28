#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <strings.h>

#include <sys/socket.h>
#include <sys/types.h>

#include <net/ethernet.h>
#include <net/route.h>

#include <netinet/in.h>

#include "rtmsg.h"

int arp_set(struct in_addr addr, struct ether_addr lladdr)
{
	struct sockaddr_in dst;
	bzero(&dst, sizeof(dst));

	dst.sin_len = sizeof(dst);
	dst.sin_family = AF_INET;
	dst.sin_addr = addr;

	struct sockaddr_dl sdl;
	bzero(&sdl, sizeof(sdl));

	sdl.sdl_len = sizeof(sdl);
	sdl.sdl_family = AF_LINK;
	sdl.sdl_alen = ETHER_ADDR_LEN;

	*(struct ether_addr *) LLADDR(&sdl) = lladdr;

	struct rt_msghdr *rtm = rtmsg(RTM_GET, &dst, NULL);
	if(rtm == NULL) {
		perror("RTM_GET");
		return -1;
	}

	struct sockaddr_in *addr_aux = (struct sockaddr_in *) (rtm + 1);
	struct sockaddr_dl *sdl_aux = (struct sockaddr_dl *) (((void *) addr_aux) + SA_SIZE(addr_aux));

	sdl.sdl_type = sdl_aux->sdl_type;
	sdl.sdl_index = sdl_aux->sdl_index;

	return (rtmsg(RTM_ADD, &dst, &sdl) == NULL) ? -1 : 0;
}
