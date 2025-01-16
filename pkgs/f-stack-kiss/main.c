#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <strings.h>
#include <time.h>

#include <errno.h>
#include <fcntl.h>
#include <getopt.h>

#include <arpa/inet.h>

#include <net/if.h>

#include <netinet/ether.h>

#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/types.h>

#include "ff_api.h"
#include "ff_config.h"

#include "arp.h"

#define die(cond) if (!(cond)) do { printf("%s: %s\n", __PRETTY_FUNCTION__, (#cond)); exit(-1); } while(false)

#define NS_IN_S 1000000000UL
#define BUF_LEN (1 << 20)
#define MAX_EVENTS 1024
#define PURE_ACK_LEN 54


uint64_t timeout;
uint8_t *buf = NULL;
uint16_t connections = 0;
uint64_t before = 0;
uint64_t data = 0;
int cnt = 0;
bool tcp;
bool udp;
uint16_t mss = 0;
int kq = -1;
struct kevent *cv, *ev;

struct sock_event {
	int fd;
	enum {
		LISTENING,
		ESTABLISHED
	} sock_type;

	__uint128_t data;
};

uint64_t time_now() {
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (ts.tv_sec * NS_IN_S) + ts.tv_nsec;
}

int loop(void *arg)
{
	if (cnt++ >= 1000) {
		uint64_t now = time_now();
		uint64_t delta = now - before;

		if (delta >= NS_IN_S) {
			__uint128_t data = 0;
			uint16_t established = 0;
	                for (uint16_t idx = 0; idx < connections; idx++) {
				struct sock_event *sev = (struct sock_event *) cv[idx].udata;
				if (sev->sock_type != ESTABLISHED)
					continue;

				established++;

				data += sev->data;
	                        sev->data = 0;
        	        }

			data = data * 8 * NS_IN_S / delta;
			printf("pps=%lu; bps=%lu; connections=%hu;\n", (uint64_t) (data / 8 / mss), (uint64_t) data, established);
			before = now;
		}

		if (now > timeout)
			exit(0);

		cnt = 0;
	}

	int nev = ff_kevent(kq, cv, connections, ev, MAX_EVENTS, NULL);
	for (int idx = 0; idx < nev; idx++) {
		struct kevent kev = ev[idx];
		struct sock_event *sev = kev.udata;

		if ((kev.fflags & EVFILT_READ) && (sev->sock_type == LISTENING)) {
			int asockfd = ff_accept(sev->fd, NULL, 0);

			int flags = ff_fcntl(asockfd, F_GETFL, 0);
			ff_fcntl(asockfd, F_SETFL, flags | O_NONBLOCK);

			struct sock_event *asev = malloc(sizeof(struct sock_event));
			asev->fd = asockfd;
			asev->sock_type = ESTABLISHED;
			asev->data = 0;

			connections++;
			EV_SET(&cv[connections - 1], asockfd, EVFILT_READ, EV_ADD | EV_ENABLE | EV_ONESHOT, 0, 0, (void *) asev);
		} else if ((kev.fflags & EVFILT_READ) && (sev->sock_type == ESTABLISHED)) {
			int len = ff_recv(sev->fd, buf, BUF_LEN, 0);
			sev->data += len;

		} else if (kev.fflags & EVFILT_WRITE) {
			ff_send(sev->fd, buf, BUF_LEN, 0);
		}
	}

	return 0;
}

struct kevent *get_eventloop(size_t n_sockets, bool udp, struct in_addr *connect_ip)
{
	if (n_sockets > (UINT16_MAX - 1024))
		return NULL;

	struct kevent *ret = malloc(sizeof(struct kevent) * n_sockets);

	for (uint16_t idx = 0; idx < n_sockets; idx++) {
		int sockfd = ff_socket(AF_INET, udp ? SOCK_DGRAM : SOCK_STREAM, 0);
		die(sockfd >= 0);

		int flags = ff_fcntl(sockfd, F_GETFL, 0);
		ff_fcntl(sockfd, F_SETFL, flags | O_NONBLOCK);

		int on = 1;
		die(ff_ioctl(sockfd, FIONBIO, &on) >= 0);

		struct sockaddr_in local_addr = {
			.sin_family = AF_INET,
			.sin_addr.s_addr = htonl(INADDR_ANY),
			.sin_port = htons(1024 + idx)
		};

		die(ff_bind(sockfd, (struct linux_sockaddr *) &local_addr, sizeof(local_addr)) >= 0);

		struct sock_event *sev = malloc(sizeof(struct sock_event));
		sev->fd = sockfd;

		if (idx % 2) {
			if (!udp) {
				sev->sock_type = LISTENING;
				die(ff_listen(sockfd, MAX_EVENTS) >= 0);
			} else
				sev->sock_type = ESTABLISHED;

			EV_SET(&ret[idx], sockfd, EVFILT_READ, EV_ADD | EV_ENABLE | EV_ONESHOT, 0, 0, (void *) sev);
		} else {
			sev->sock_type = ESTABLISHED;
			EV_SET(&ret[idx], sockfd, EVFILT_WRITE, EV_ADD | EV_ENABLE | EV_ONESHOT, 0, 0, (void *) sev);

			struct sockaddr_in remote_addr = {
				.sin_family = AF_INET,
				.sin_addr = *connect_ip,
				.sin_port = htons(1024 + idx + 1)
			};

			if ((ff_connect(sockfd, (struct linux_sockaddr *) &remote_addr, sizeof(remote_addr)) < 0) && (errno != EINPROGRESS))
				die(false);
		}
	}

	return ret;
}

int main(int argc, char * argv[])
{
	die(ff_init(argc, argv) >= 0);

	static struct option long_options[] = {
		{ "connect-ip", required_argument, 0, 0 },
		{ "tcp", no_argument, 0, 0 },
		{ "udp", no_argument, 0, 0 },
		{ "mss", required_argument, 0, 0 },
		{ "arp", required_argument, 0, 0 },
		{ "connections", required_argument, 0, 0 },
		{ "timeout", required_argument, 0, 0 },
		{ NULL, 0, 0, 0}
	};

	char opt;
	int option_index;

	timeout = 0;
	struct in_addr connect_ip = { .s_addr = 0 };

	udp = false;
	tcp = false;

	char *eth_str = NULL;
	struct in_addr nei_addr;
	void *tmp8 = NULL;
	struct ether_addr nei_lladdr;

	int tmp1;

	while ((opt = getopt_long(argc, argv, "", long_options, &option_index)) != -1) {
		die(opt == 0);

		switch (option_index) {
			case 0:
				die(inet_pton(AF_INET, optarg, &connect_ip) != 0);
				break;

			case 1:
				tcp = true;
				break;

			case 2:
				udp = true;
				break;

			case 3:
				mss = atoi(optarg);
				break;

			case 4:
				eth_str = strchr(optarg, ':');
				die(eth_str != NULL);
				*eth_str++ = '\0';

				die(inet_pton(AF_INET, optarg, &nei_addr) != 0);

				tmp8 = ether_aton(eth_str);
				die(tmp8 != NULL);
				nei_lladdr = *(struct ether_addr *) tmp8;

				die(arp_set(nei_addr, nei_lladdr) >= 0);
				break;

			case 5:
				tmp1 = atoi(optarg);
				die((tmp1 > 0) && ((tmp1 * 2) < (UINT16_MAX - 1024)));
				connections = tmp1;
				break;

			case 6:
				timeout = atoi(optarg);;
				break;

			default:
				break;
		}
	}

	die(connect_ip.s_addr != 0);
	die(connections > 0);
	die(mss != 0);
	die(tcp ^ udp);
	die(timeout > 0);

	buf = malloc(sizeof(uint8_t) * BUF_LEN);
	kq = ff_kqueue();
	ev = malloc(sizeof(struct kevent) * MAX_EVENTS);
	cv = get_eventloop(connections, udp, &connect_ip);
	before = time_now();
	timeout = time_now() + (timeout * NS_IN_S);

	ff_run(loop, NULL);

	return 0;
}
