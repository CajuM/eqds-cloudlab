#ifndef _H_FSTAKC_PERF_RTMSG_H_
#define _H_FSTAKC_PERF_RTMSG_H_

#include <sys/socket.h>
#include <sys/types.h>

#include <net/if_dl.h>

#include <netinet/in.h>

struct rt_msghdr *rtmsg(int cmd, struct sockaddr_in *dst, struct sockaddr_dl *sdl);

#endif
