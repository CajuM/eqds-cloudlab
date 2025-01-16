num:

{ pkgs, lib, ... }:

{
  virtualisation.memorySize = 6144;
  virtualisation.cores = 2;

  virtualisation.qemu.networkingOptions = lib.mkForce [
    "-chardev socket,id=char1,server=off,path=/tmp/dpdk${toString num}"
    "-netdev vhost-user,id=hostnet1,chardev=char1,vhostforce=on"
    "-device virtio-net-pci,bus=pcie.0,addr=10.0,netdev=hostnet1,id=net1,mac=12:23:34:45:56:0${toString num},rx_queue_size=1024,tx_queue_size=1024,mrg_rxbuf=off,rss=off,mq=off,csum=on,guest_csum=on"
    "-netdev tap,id=hostnet2,script=${./qemu-ifup${toString num}.sh}"
    "-device virtio-net-pci,netdev=hostnet2,id=net2"
  ];

  virtualisation.qemu.options = [
    "-display none"
    "-serial mon:stdio"
    "-machine q35,accel=kvm"
    "-cpu host,+x2apic,-pmu"
    "-object memory-backend-file,id=mem,size=6144M,mem-path=/dev/hugepages,share=on"
    "-mem-prealloc"
    "-numa node,memdev=mem"
    "-name qemu,debug-threads=on"
  ];

  boot.extraModprobeConfig = ''
    options vfio enable_unsafe_noiommu_mode=1
  '';

  boot.kernelModules = [ "vfio-pci" ];
  boot.kernelPackages = pkgs.myLinuxPackages;
  boot.kernelParams = [
    "default_hugepagesz=2M"
    "hugepagesz=2M"
    "hugepages=2048"
    "isolcpus=1"
    "nohz_full=1"
    "rcu_nocbs=1"
    "rcu_nocb_poll"
    "iommu=pt"
  ];

  networking = {
    dhcpcd.enable = false;
    firewall.enable = false;
    interfaces.eth0.ipv4.addresses = [
      {
        address = "10.2.${toString num}.1";
        prefixLength = 24;
      }
    ];
  };

  users.mutableUsers = false;

  users.users.root = {
    initialHashedPassword = "";
  };

  services.openssh = {
    enable = true;

    settings = {
      PermitRootLogin = "yes";
      PermitEmptyPasswords = true;
      UsePAM = false;
      AuthenticationMethods = "none";
    };
  };

  environment.systemPackages = with pkgs; [
    dpdk
    ethtool
    gdb
    htop
    iperf2
    iperf3
    lsof
    myLinuxPackages.perf
    python312Packages.scapy
    tmux
    valgrind
    wireshark-cli
    f-stack-kiss
    libndpip-kiss
    mtcp-kiss
  ];

  security.pam.loginLimits = [
    {
      domain = "*";
      item = "nofile";
      type = "soft";
      value = "524288";
    }
    {
      domain = "*";
      item = "nofile";
      type = "hard";
      value = "524288";
    }
  ];

  services.getty.autologinUser = "root";

  systemd.services.setup = {
    path = with pkgs; [
      dpdk
      dpdk-iface
      dpdk-iface-kmod-vm
      kmod
      iproute2
      which
    ];
    serviceConfig.Type = "oneshot";
    wantedBy = [ "multi-user.target" ];

    script = ''
      # General set-up
      dpdk-devbind.py --force -b vfio-pci 00:10.0

      # Set-up mTCP
      insmod ${pkgs.dpdk-iface-kmod-vm}/dpdk_iface.ko
      dpdk_iface_main

      ip addr add 10.1.1.${toString num}/24 dev dpdk0
      ip link set dpdk0 up

      cd /root
      mkdir -p config
      cp ${./arp.conf.${toString num}} config/arp.conf
      cp ${./perf.conf} perf.conf
    '';
  };

  system.stateVersion = "24.11";
}
