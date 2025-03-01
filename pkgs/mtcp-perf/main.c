#include <assert.h>
#include <errno.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <getopt.h>

#include <arpa/inet.h>

#include <netinet/ether.h>
#include <netinet/in.h>
#include <netinet/tcp.h>

#include <sys/socket.h>

#include <mtcp_api.h>
#include <mtcp_epoll.h>


#define MAX_LISTENING_EVENTS 1024
#define NS_IN_S 1000000000UL
#define BUF_LEN (1 << 27)

mctx_t mctx = NULL;
uint64_t mss = 0;
static bool running = true;
struct sock_event {
	int fd;
	enum {
		ESTABLISHED,
		LISTENING
	} sock_type;
	__uint128_t data;
};

#define die(cond) if (!(cond)) do { printf("%s: %s\n", __PRETTY_FUNCTION__, (#cond)); exit(-1); } while(false)


int get_eventloop(size_t n_sockets, struct sockaddr_in *local_addr, struct sockaddr_in *remote_addr)
{
	int ret = mtcp_epoll_create1(mctx, 0);

	if (remote_addr == NULL)
		n_sockets = 1;

	for (size_t idx = 0; idx < n_sockets; idx++) {
		int sockfd = mtcp_socket(mctx, AF_INET, SOCK_STREAM, 0);
		die(sockfd >= 0);

		die(mtcp_setsock_nonblock(mctx, sockfd) >= 0);
		die(mtcp_bind(mctx, sockfd, (struct sockaddr *) local_addr, sizeof(struct sockaddr_in)) >= 0);

		struct mtcp_epoll_event ev;
		ev.data.ptr = malloc(sizeof(struct sock_event));
		((struct sock_event *) ev.data.ptr)->fd = sockfd;

		if (remote_addr == NULL) {
			((struct sock_event *) ev.data.ptr)->sock_type = LISTENING;
			ev.events = MTCP_EPOLLIN;
			die(mtcp_listen(mctx, sockfd, 1024) >= 0);
		} else {
			((struct sock_event *) ev.data.ptr)->sock_type = ESTABLISHED;
			ev.events = MTCP_EPOLLOUT;
			if ((mtcp_connect(mctx, sockfd, (struct sockaddr *) remote_addr, sizeof(struct sockaddr_in)) < 0) && (errno != EINPROGRESS))
				die(false);
		}

		mtcp_epoll_ctl(mctx, ret, MTCP_EPOLL_CTL_ADD, sockfd, &ev);
	}

	return ret;
}

int main(int argc, char **argv)
{
	static struct option long_options[] = {
		{ "listen", no_argument, 0,  0 },
		{ "connect-ip", required_argument, 0,  0 },
		{ "bind-port", required_argument, 0,  0 },
		{ "connect-port", required_argument, 0,  0 },
		{ "timeout", required_argument, 0, 0 },
		{ "connections", required_argument, 0, 0 },
		{ NULL, 0, 0, 0 }
	};

	char opt;
	int option_index;

	uint16_t bind_port = 0;

	bool listening = false;

	bool connecting = false;
	struct in_addr connect_ip;
	uint16_t connect_port = 0;

	uint64_t timeout = 0;
	uint64_t connections = 0;

	while ((opt = getopt_long(argc, argv, "", long_options, &option_index)) != -1) {
		die(opt == 0);

		switch (option_index) {
			case 0:
				listening = true;
				break;

			case 1:
				die(inet_aton(optarg, &connect_ip) != 0);
				connecting = true;
				break;

			case 2:
				bind_port = atoi(optarg);
				break;

			case 3:
				connect_port = atoi(optarg);
				break;

			case 4:
				timeout = atoi(optarg);
				break;

			case 5:
				connections = atoi(optarg);
				die(connections > 0);
				break;

			default:
				die(false);
				break;
		}
	}

	char *tmp_mss = getenv("MTCP_MSS");
	die(tmp_mss != NULL);
	mss = atol(tmp_mss);

	die(listening ^ connecting);
	die((timeout && connecting) || !timeout);
	die(!(connections && !connecting));
	die(!(bind_port && !listening));
	die(!(connecting && !connect_port));

	char *conf_file = getenv("MTCP_CONFIG");
	die(conf_file != NULL);
	die(mtcp_init(conf_file) >= 0);
	mctx = mtcp_create_context(1);

	struct sockaddr_in local_addr = {
		.sin_family = AF_INET,
		.sin_addr.s_addr = htonl(INADDR_ANY),
	};

	if (connecting) {
		local_addr.sin_port = 0;

		struct sockaddr_in remote_addr = {
			.sin_family = AF_INET,
			.sin_addr = connect_ip,
			.sin_port = htons(connect_port)
		};

		int ep = get_eventloop(connections, &local_addr, &remote_addr);
		struct mtcp_epoll_event *ev = malloc(sizeof(struct mtcp_epoll_event) * connections);

		void *buf = malloc(BUF_LEN);

		struct timespec timeout_ts;
		clock_gettime(CLOCK_MONOTONIC, &timeout_ts);

		while (running) {
			int n_events = mtcp_epoll_wait(mctx, ep, ev, connections, 0);
			for (size_t idx = 0; idx < n_events; idx++) {
				struct sock_event sev = *((struct sock_event *) ev[idx].data.ptr);

				if (ev[idx].events & MTCP_EPOLLHUP) {
					mtcp_close(mctx, sev.fd);
					mtcp_epoll_ctl(mctx, ep, MTCP_EPOLL_CTL_DEL, sev.fd, NULL);

					perror("Connection closed");
					return -1;
				}

				if (ev[idx].events & MTCP_EPOLLOUT)
					mtcp_write(mctx, sev.fd, buf, BUF_LEN);
			}

			if (timeout) {
				struct timespec now;
				clock_gettime(CLOCK_MONOTONIC, &now);

				if ((now.tv_sec - timeout_ts.tv_sec) >= timeout)
					break;
			}
		}
	} else {
		local_addr.sin_port = htons(bind_port);

		int ep = get_eventloop(0, &local_addr, NULL);
		struct mtcp_epoll_event ev[MAX_LISTENING_EVENTS];
		void *buf = malloc(BUF_LEN);

		struct timespec before;
		clock_gettime(CLOCK_MONOTONIC, &before);

		uint64_t n_sev = 0;
		struct sock_event **sevs = NULL;

		while (running) {
			int n_events = mtcp_epoll_wait(mctx, ep, ev, MAX_LISTENING_EVENTS, 0);
			for (size_t idx = 0; idx < n_events; idx++) {
				struct sock_event *sev = ((struct sock_event *) ev[idx].data.ptr);

				if ((sev->sock_type == LISTENING) && (ev[idx].events & MTCP_EPOLLIN)) {
					int asockfd = mtcp_accept(mctx, sev->fd, NULL, NULL);
					die(mtcp_setsock_nonblock(mctx, asockfd) >= 0);

					struct mtcp_epoll_event ev;
					ev.data.ptr = malloc(sizeof(struct sock_event));
					((struct sock_event *) ev.data.ptr)->fd = asockfd;
					((struct sock_event *) ev.data.ptr)->sock_type = ESTABLISHED;

					ev.events = MTCP_EPOLLIN;

					mtcp_epoll_ctl(mctx, ep, MTCP_EPOLL_CTL_ADD, asockfd, &ev);

					n_sev++;
                                        sevs = realloc(sevs, n_sev * sizeof(struct sock_event *));
                                        sevs[n_sev - 1] = ev.data.ptr;
                                        sevs[n_sev - 1]->data = 0;
				}

				if (ev[idx].events & MTCP_EPOLLHUP) {
					mtcp_close(mctx, sev->fd);
					mtcp_epoll_ctl(mctx, ep, MTCP_EPOLL_CTL_DEL, sev->fd, NULL);

					perror("Connection closed");
					return -1;
				}

				if ((sev->sock_type == ESTABLISHED) && (ev[idx].events & MTCP_EPOLLIN)) {
					int r = mtcp_read(mctx, sev->fd, buf, BUF_LEN);
					if (r > 0)
						sev->data += r;
				}
			}

			struct timespec now;
			clock_gettime(CLOCK_MONOTONIC, &now);

			uint64_t delta = (now.tv_sec - before.tv_sec) * NS_IN_S + (now.tv_nsec - before.tv_nsec);
			if (delta >= NS_IN_S) {
				__uint128_t data = 0;
				for (uint64_t idx = 0; idx < n_sev; idx++) {
					data += sevs[idx]->data;
					sevs[idx]->data = 0;
				}

				data = data * 8 * NS_IN_S / delta;
				printf("pps=%lu; bps=%lu; connections=%lu;\n", (uint64_t) (data / 8 / mss), (uint64_t) data, n_sev);
				before = now;
			}
		}
	}

	return 0;
}
