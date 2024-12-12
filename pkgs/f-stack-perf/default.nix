{ stdenv
, lib
, pkg-config
, dpdk
, f-stack
, jansson
, libelf
, libnl
, libpcap
, numactl
, openssl
, zlib
}:

stdenv.mkDerivation rec {
  pname = "f-stack-perf";
  version = "0";
  src = ./.;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    jansson
    libelf
    libnl
    libpcap
    numactl
    openssl
    zlib
    dpdk
    f-stack
  ];

  dontStrip = true;

  CFLAGS = lib.concatStringsSep " " [ ];

  makeFlags = [ "F_STACK=${f-stack}" ];

  installPhase = ''
    mkdir -p $out/bin
    cp f-stack-perf $out/bin
  '';
}
