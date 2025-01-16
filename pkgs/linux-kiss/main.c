#include <assert.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <unistd.h>

#include <arpa/inet.h>

#include <netinet/ether.h>
#include <netinet/in.h>
#include <netinet/tcp.h>

#include <sys/epoll.h>
#include <sys/socket.h>

#define MAX_LISTENING_EVENTS 1024
#define NS_IN_S 1000000000UL
#define BUF_LEN (1 << 27)

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


int get_eventloop(uint16_t n_sockets, struct in_addr *connect_ip)
{
	if (n_sockets > (UINT16_MAX - 1024))
		return -1;

	int ret = epoll_create1(0);

	for (uint16_t idx = 0; idx < n_sockets; idx++) {
		int sockfd = socket(AF_INET, SOCK_STREAM, 0);
		die(sockfd >= 0);

		int flags = fcntl(sockfd, F_GETFL, 0);
		fcntl(sockfd, F_SETFL, flags | O_NONBLOCK);

		struct sockaddr_in local_addr = {
			.sin_family = AF_INET,
			.sin_addr.s_addr = htonl(INADDR_ANY),
			.sin_port = htons(1024 + idx)
		};

		die(bind(sockfd, (struct sockaddr *) &local_addr, sizeof(struct sockaddr_in)) >= 0);

		struct epoll_event ev;
		ev.data.ptr = malloc(sizeof(struct sock_event));
		((struct sock_event *) ev.data.ptr)->fd = sockfd;

		if (idx % 2) {
			((struct sock_event *) ev.data.ptr)->sock_type = LISTENING;
			ev.events = EPOLLIN;
			die(listen(sockfd, 1024) >= 0);
		} else {
			((struct sock_event *) ev.data.ptr)->sock_type = ESTABLISHED;
			ev.events = EPOLLOUT;

			struct sockaddr_in remote_addr = {
				.sin_family = AF_INET,
				.sin_addr = *connect_ip,
				.sin_port = htons(1024 + idx + 1)
			};

			if ((connect(sockfd, (struct sockaddr *) &remote_addr, sizeof(struct sockaddr_in)) < 0) && (errno != EINPROGRESS))
				die(false);
		}

		epoll_ctl(ret, EPOLL_CTL_ADD, sockfd, &ev);
	}

	return ret;
}

uint64_t time_now() {
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (ts.tv_sec * NS_IN_S) + ts.tv_nsec;
}

int main(int argc, char **argv)
{
	static struct option long_options[] = {
		{ "connect-ip", required_argument, 0,  0 },
		{ "timeout", required_argument, 0, 0 },
		{ "connections", required_argument, 0, 0 },
		{ "mss", required_argument, 0, 0 },
		{ "iface", required_argument, 0, 0 },
		{ NULL, 0, 0, 0 }
	};

	char opt;
	int option_index;

	struct in_addr connect_ip;
	uint64_t timeout = 0;
	uint16_t connections = 0;
	int mss = 1460;
	char *iface = NULL;

	int tmp1 = 0;

	while ((opt = getopt_long(argc, argv, "", long_options, &option_index)) != -1) {
		die(opt == 0);

		switch (option_index) {
			case 0:
				die(inet_aton(optarg, &connect_ip) != 0);
				break;

			case 1:
				timeout = atoi(optarg);
				break;

			case 2:
				tmp1 = atoi(optarg);
				die((tmp1 > 0) && ((tmp1 * 2) <= (UINT16_MAX - 1024)));
				connections = tmp1;
				break;

			case 3:
				mss = atoi(optarg);
				die((mss <= 1460) && (mss > 0));
				break;

			case 4:
				iface = malloc((strlen(optarg) + 1) * sizeof(char));
				strcpy(iface, optarg);
				break;

			default:
				die(false);
				break;
		}
	}

	die(timeout > 0);
	die(connections > 0);

	char *cmd;
	die(asprintf(&cmd, "ip link set dev %s mtu %d", iface, mss + 40) > 0);
	die(unsetenv("LD_PRELOAD") == 0);
	die(system(cmd) == 0);

	free(iface);
	free(cmd);

	int ep = get_eventloop(connections, &connect_ip);
	struct epoll_event *ev = malloc(connections * sizeof(struct epoll_event));
	struct sock_event **sevs = malloc(connections * sizeof(struct sock_event *));

	void *buf = malloc(BUF_LEN);

	timeout = time_now() + (timeout * NS_IN_S);

	uint16_t n_sev = 0;
	uint64_t before = 0;

	while (running) {
		int n_events = epoll_wait(ep, ev, connections, 0);
		for (size_t idx = 0; idx < n_events; idx++) {
			struct sock_event *sev = (struct sock_event *) ev[idx].data.ptr;

			if (ev[idx].events & EPOLLHUP) {
				epoll_ctl(ep, EPOLL_CTL_DEL, sev->fd, NULL);
				close(sev->fd);

				perror("Connection closed");
				return -1;
			}

			if (ev[idx].events & EPOLLOUT) {
				int r = write(sev->fd, buf, BUF_LEN);
				if ((r < 0) && ((errno != EAGAIN) || (errno != ENOSPC)))
					perror("write");
			}

			if ((sev->sock_type == LISTENING) && (ev[idx].events & EPOLLIN)) {
				int asockfd = accept(sev->fd, NULL, NULL);

				int flags = fcntl(asockfd, F_GETFL, 0);
				fcntl(asockfd, F_SETFL, flags | O_NONBLOCK);

				struct epoll_event ev;
				ev.data.ptr = malloc(sizeof(struct sock_event));
				((struct sock_event *) ev.data.ptr)->fd = asockfd;
				((struct sock_event *) ev.data.ptr)->sock_type = ESTABLISHED;

				ev.events = EPOLLIN;

				epoll_ctl(ep, EPOLL_CTL_ADD, asockfd, &ev);

				n_sev++;
				sevs[n_sev - 1] = ev.data.ptr;
				sevs[n_sev - 1]->data = 0;
			}

			if ((sev->sock_type == ESTABLISHED) && (ev[idx].events & EPOLLIN)) {
				int r = read(sev->fd, buf, BUF_LEN);
				if (r > 0)
					sev->data += r;
			}
		}

		uint64_t now = time_now();

		uint64_t delta = now - before;
		if (delta >= NS_IN_S) {
			__uint128_t data = 0;
			for (uint64_t idx = 0; idx < n_sev; idx++) {
				data += sevs[idx]->data;
				sevs[idx]->data = 0;
			}

			data = data * 8 * NS_IN_S / delta;
			printf("pps=%lu; bps=%lu; connections=%hu;\n", (uint64_t) (data / 8 / mss), (uint64_t) data, n_sev);
			before = now;
		}

		if (now > timeout)
			break;
	}

	return 0;
}
