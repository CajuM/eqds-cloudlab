{ stdenv
, lib
, pkg-config
, dpdk
, jansson
, gmp
, libelf
, libmnl
, libnl
, libpcap
, mtcp
, numactl
, openssl
, rdma-core
, zlib
}:

stdenv.mkDerivation rec {
  pname = "mtcp-perf";
  version = "0";
  src = ./.;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    dpdk
    jansson
    gmp
    libelf
    libmnl
    libnl
    libpcap
    mtcp
    numactl
    openssl
    rdma-core
    zlib
  ];

  dontStrip = true;

  CFLAGS = lib.concatStringsSep " " [ ];

  makeFlags = [
    "GMP=${gmp}"
    "MTCP=${mtcp}"
    "RTE_SDK=${dpdk}/share/dpdk"
    "RTE_TARGET=x86_64-native-linuxapp-gcc"
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp build/mtcp-perf $out/bin/
  '';

  enableParallelBuilding = true;
}
