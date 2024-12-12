{ pkgs
, lib
, stdenv
, pkg-config
, boost
, jansson
, libbsd
, libelf
, libnl
, libpcap
, nlohmann_json
, numactl
, openssl
, zlib
, dpdk
}:

stdenv.mkDerivation {
  name = "eqdsshim";

  src = ./src;

  passthru = {
    inherit dpdk;
  };

  dontStrip = true;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    boost
    jansson
    libbsd
    libelf
    libnl
    libpcap
    nlohmann_json
    numactl
    openssl
    zlib
    dpdk
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp eqdsshim $out/bin
  '';
}
