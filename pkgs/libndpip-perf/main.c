#include <assert.h>
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

#include <rte_pdump.h>

#include <ndpip/socket.h>
#include <ndpip/epoll.h>
#include <ndpip/linux_dpdk.h>


#define MAX_LISTENING_EVENTS 2048
#define NS_IN_S 1000000000UL
#define MS_IN_S 1000
#define MAX_PKTS (1 << 15)
#define BUF_LEN (1 << 20)

#ifdef NDPIP_GRANTS_ENABLE
extern bool ndpip_log_grants;

extern int64_t (*ndpip_log_grants_msg)[5];
extern int64_t ndpip_log_grants_idx;

extern int64_t (*ndpip_log_grants_tcp)[3];
extern int64_t ndpip_log_grants_tcp_idx;
extern char *ndpip_log_grants_tcp_logtags[3];
#endif

static struct timespec *log = NULL;
uint64_t log_idx = 0;
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


int get_eventloop(size_t n_sockets, bool udp, int mss, uint8_t win_scale, struct sockaddr_in *local_addr, struct sockaddr_in *remote_addr)
{
	int ret = ndpip_epoll_create1(0);

	if (remote_addr == NULL)
		n_sockets = 1;

	for (size_t idx = 0; idx < n_sockets; idx++) {
		int sockfd = ndpip_socket(AF_INET, SOCK_NDPIP | SOCK_NONBLOCK, udp ? IPPROTO_UDP : IPPROTO_TCP);
		die(sockfd >= 0);

		die(ndpip_setsockopt(sockfd, SOL_SOCKET, SO_NDPIP_MAX_TX_SEG, &mss, sizeof(int)) >= 0);

		if (!udp) {
			die(ndpip_setsockopt(sockfd, SOL_SOCKET, SO_NDPIP_TCP_WIN_SCALE, &win_scale, sizeof(uint8_t)) >= 0);
			die(ndpip_setsockopt(sockfd, SOL_SOCKET, SO_NDPIP_TCP_MAX_RX_SEG, &mss, sizeof(int)) >= 0);
		}

		die(ndpip_bind(sockfd, (struct sockaddr *) local_addr, sizeof(struct sockaddr_in)) >= 0);

		struct epoll_event ev;

		ev.data.ptr = malloc(sizeof(struct sock_event));
		((struct sock_event *) ev.data.ptr)->fd = sockfd;

		if (remote_addr == NULL) {
			((struct sock_event *) ev.data.ptr)->sock_type = udp ? ESTABLISHED : LISTENING;

			ev.events = EPOLLIN;

			if (!udp)
				die(ndpip_listen(sockfd, 1024) >= 0);
		} else {
			((struct sock_event *) ev.data.ptr)->sock_type = ESTABLISHED;

			ev.events = EPOLLOUT;

			die(ndpip_connect(sockfd, (struct sockaddr *) remote_addr, sizeof(struct sockaddr_in)) >= 0);
		}

		ndpip_epoll_ctl(ret, EPOLL_CTL_ADD, sockfd, &ev);
	}

	return ret;
}

void exit_handler(int s)
{
#ifdef NDPIP_GRANTS_ENABLE
	for (size_t idx = 0; idx < ndpip_log_grants_idx; idx++) {
		printf("grants msg: grants=%ld; operation=%ld; destination=%lx; value1=%ld; value2=%ld;\n",
			ndpip_log_grants_msg[idx][0],
			ndpip_log_grants_msg[idx][1],
			ndpip_log_grants_msg[idx][2],
			ndpip_log_grants_msg[idx][3],
			ndpip_log_grants_msg[idx][4]);
	}
	
	for (size_t idx = 0; idx < ndpip_log_grants_tcp_idx; idx++) {
		printf("grants tcp/%s(): sock_grants=%ld; grants_dec=%ld;\n",
			ndpip_log_grants_tcp_logtags[ndpip_log_grants_tcp[idx][2]],
			ndpip_log_grants_tcp[idx][0],
			ndpip_log_grants_tcp[idx][1]);
	}
#endif

	for (size_t idx = 0; idx < log_idx; idx++)
		printf("%lu.%lu\n", log[idx].tv_sec, log[idx].tv_nsec);

	running = false;
}

int main(int argc, char **argv)
{
	static struct option long_options[] = {
		{ "bind-ip", required_argument, 0,  0 },
		{ "dev", required_argument, 0,  0 },
		{ "listen", no_argument, 0,  0 },
		{ "connect-ip", required_argument, 0,  0 },
		{ "bind-eth", required_argument, 0,  0 },
		{ "bind-port", required_argument, 0,  0 },
		{ "connect-port", required_argument, 0,  0 },
		{ "arp", required_argument, 0, 0 },
		{ "burst", required_argument, 0, 0 },
		{ "win-scale", required_argument, 0, 0 },
		{ "mss", required_argument, 0, 0 },
		{ "log-grants", no_argument, 0, 0 },
		{ "udp", no_argument, 0, 0 },
		{ "tcp", no_argument, 0, 0 },
		{ "timeout", required_argument, 0, 0 },
		{ "connections", required_argument, 0, 0 },
		{ "iface", required_argument, 0, 0 },
		{ NULL, 0, 0, 0 }
	};

	char opt;
	int option_index;

	struct in_addr bind_ip;
	struct ether_addr bind_eth;
	uint16_t bind_port = 0;

	bool bound_ip = false;
	bool bound_eth = false;

	bool listening = false;

	bool connecting = false;
	struct in_addr connect_ip;
	uint16_t connect_port = 0;

	size_t arp_len = 0;
	struct ndpip_arp_peer arp_table[10];

	uint16_t burst = 0;
	int mss = 1460;
	uint8_t win_scale = 1;

	bool tcp = false;
	bool udp = false;

	uint64_t timeout = 0;
	uint64_t connections = 0;

	int iface = -1;

        int argc_rte = rte_eal_init(argc, argv);
        if (argc_rte < 0)       
                rte_exit(-1, "Can not init DPDK\n");

        argc -= argc_rte;
        argv += argc_rte;

	while ((opt = getopt_long(argc, argv, "", long_options, &option_index)) != -1) {
		die(opt == 0);

		struct ether_addr *tmp5;
		char *eth_str;
		struct ether_addr *tmp8;
		int tmp_burst;
		int tmp_win_scale;

		switch (option_index) {
			case 0:
				die(inet_aton(optarg, &bind_ip) != 0);
				bound_ip = true;
				break;

			case 2:
				listening = true;
				break;

			case 3:
				die(inet_aton(optarg, &connect_ip) != 0);
				connecting = true;
				break;

			case 4:
				tmp5 = ether_aton(optarg);
				die(tmp5 != NULL);
				bind_eth = *tmp5;
				bound_eth = true;
				break;

			case 5:
				bind_port = atoi(optarg);
				break;

			case 6:
				connect_port = atoi(optarg);
				break;

			case 7:
				eth_str = strchr(optarg, ':');
				die(eth_str != NULL);
				*eth_str++ = '\0';

				die(inet_aton(optarg, &arp_table[arp_len].inaddr) != 0);
				tmp8 = ether_aton(eth_str);
				die(tmp8 != NULL);
				arp_table[arp_len++].ethaddr = *tmp8;
				break;

			case 8:
				tmp_burst = atoi(optarg);
				die(tmp_burst > 0);
				burst = tmp_burst;
				break;

			case 9:
				tmp_win_scale = atoi(optarg);
				die((tmp_win_scale <= 14) && (tmp_win_scale >= 0));
				win_scale = tmp_win_scale;
				break;

			case 10:
				mss = atoi(optarg);
				die((mss <= 1460) && (mss > 0));
				break;

			case 11:
#ifdef NDPIP_GRANTS_ENABLE
				ndpip_log_grants = true;
#else
				printf("ERROR: ndpip has not been compiled with grants enabled\n");
				return -1;
#endif
				break;

			case 12:
				udp = true;
				break;

			case 13:
				tcp = true;
				break;

			case 14:
				timeout = atoi(optarg);
				break;

			case 15:
				connections = atoi(optarg);
				die(connections > 0);
				break;

			case 16:
				iface = atoi(optarg);
				die(iface >= 0);
				break;

			default:
				die(false);
				break;
		}
	}

#ifdef NDPIP_GRANTS_ENABLE
	ndpip_log_grants_msg = malloc(sizeof(int64_t) * 5 * 1024 * 1024);
	ndpip_log_grants_tcp = malloc(sizeof(int64_t) * 3 * 1024 * 1024);
#endif

	signal(SIGINT, exit_handler);

	die(bound_ip && bound_eth);
	die(listening ^ connecting);
	die(udp ^ tcp);
	die(burst != 0);
	die((timeout && connecting) || !timeout);
	die(!(!!connections ^ connecting));
	die(!(!!connect_port ^ connecting));
	die(bind_port || connecting);
	die(iface >= 0);

	arp_table[arp_len].inaddr = connect_ip;
	arp_table[arp_len++].ethaddr = *ether_aton("ff:ff:ff:ff:ff:ff");

	die(rte_pdump_init() >= 0);

	ndpip_linux_dpdk_init();
	die(ndpip_linux_dpdk_register_iface(iface) >= 0);
	die(ndpip_linux_dpdk_set_ethaddr(iface, bind_eth) >= 0);
	die(ndpip_linux_dpdk_set_inaddr(iface, bind_ip) >= 0);
	die(ndpip_linux_dpdk_set_arp_table(iface, arp_table, arp_len) >= 0);
	die(ndpip_linux_dpdk_set_burst_size(iface, burst) >= 0);
	die(ndpip_linux_dpdk_start_iface(iface) >= 0);

	struct sockaddr_in local_addr = {
		.sin_family = AF_INET,
		.sin_addr = bind_ip,
		.sin_port = htons(bind_port)
	};

	void *buf = malloc(sizeof(uint8_t) * BUF_LEN);

	if (connecting) {
		struct sockaddr_in remote_addr = {
			.sin_family = AF_INET,
			.sin_addr = connect_ip,
			.sin_port = htons(connect_port)
		};

		int ep = get_eventloop(connections, udp, mss, win_scale, &local_addr, &remote_addr);
		struct epoll_event *ev = malloc(sizeof(struct epoll_event) * connections);

		struct timespec timeout_ts;
		ndpip_time_now(&timeout_ts);

		while (running) {
			int n_events = ndpip_epoll_wait(ep, ev, connections, 0);
			if (n_events < 0) {
				perror("epoll");
				goto ret;
			}

			for (size_t idx = 0; idx < n_events; idx++) {
				struct sock_event sev = *((struct sock_event *) ev[idx].data.ptr);

				if (ev[idx].events & EPOLLHUP) {
					ndpip_close(sev.fd);
					ndpip_epoll_ctl(ep, EPOLL_CTL_DEL, sev.fd, NULL);

					perror("Connection closed");
					goto ret;
				}

				if (ev[idx].events & EPOLLOUT) {
					ssize_t ret = ndpip_write(sev.fd, buf, BUF_LEN);
					if ((ret < 0) && (errno != ENOMEM))
						goto ret;
				}
			}

			if (timeout) {
				struct timespec now;
				ndpip_time_now(&now);

				if ((now.tv_sec - timeout_ts.tv_sec) >= timeout)
					break;
			}
		}
	} else {
		int ep = get_eventloop(0, udp, mss, win_scale, &local_addr, NULL);
		struct epoll_event ev[MAX_LISTENING_EVENTS];

		log = malloc(sizeof(struct timespec) * (1 << 26));

		struct timespec before;
		ndpip_time_now(&before);

		uint64_t n_sev = 0;
		struct sock_event **sevs = NULL;

		while (running) {
			int n_events = ndpip_epoll_wait(ep, ev, MAX_LISTENING_EVENTS, MS_IN_S);
			if (n_events < 0) {
				perror("epoll");
				goto ret;
			}

			for (size_t idx = 0; idx < n_events; idx++) {
				struct sock_event *sev = ((struct sock_event *) ev[idx].data.ptr);

				if (tcp && (sev->sock_type == LISTENING) && (ev[idx].events & EPOLLIN)) {
					int asockfd = ndpip_accept(sev->fd, NULL, NULL);
					if (asockfd < 0)
						continue;

					struct epoll_event ev;
					ev.data.ptr = malloc(sizeof(struct sock_event));
					((struct sock_event *) ev.data.ptr)->fd = asockfd;
					((struct sock_event *) ev.data.ptr)->sock_type = ESTABLISHED;

					ev.events = EPOLLIN;

					ndpip_epoll_ctl(ep, EPOLL_CTL_ADD, asockfd, &ev);

					n_sev++;
					sevs = realloc(sevs, n_sev * sizeof(struct sock_event *));
					sevs[n_sev - 1] = ev.data.ptr;
					sevs[n_sev - 1]->data = 0;
				}

				if (ev[idx].events & EPOLLHUP) {
					ndpip_close(sev->fd);
					ndpip_epoll_ctl(ep, EPOLL_CTL_DEL, sev->fd, NULL);

					perror("Connection closed");
					goto ret;
				}

				if ((sev->sock_type == ESTABLISHED) && (ev[idx].events & EPOLLIN)) {
					ssize_t r = ndpip_read(sev->fd, buf, BUF_LEN);
					if (r <= 0)
						continue;

					sev->data += r;
				}
			}

			struct timespec now;
			ndpip_time_now(&now);

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

ret:
	die(ndpip_linux_dpdk_stop_iface(iface) >= 0);
	rte_eal_cleanup();
	return 0;
}
