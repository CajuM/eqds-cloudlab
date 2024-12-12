{ stdenv
, lib
, fetchFromGitHub
, autoconf
, automake
, bc
, pkg-config
, gmp
, libbsd
, libmnl
, numactl
, rdma-core
, machine
, disableTxHwCksum
}:

let
  pname = "mtcp";
  src = fetchFromGitHub {
    owner = "mtcp-stack";
    repo = pname;
    rev = "0463aad5ecb6b5bca85903156ce1e314a58efc19";
    sha256 = "sha256-pwEdBjwQxphwrc2eDw1laTaeomLHH6m8H0v7Yv40pBU=";
  };

  dpdk = stdenv.mkDerivation {
    name = "dpdk-${pname}";
    src = fetchFromGitHub {
      owner = "dpdk";
      repo = "dpdk";
      rev = "a5dce55556286cc56655320d975c67b0dbe08693";
      sha256 = "sha256-oYmK80pFa8KAEJqiz9hFz7FMZtTrEgEITBRy7flVqJM=";
    };

    nativeBuildInputs = [ pkg-config ];

    buildInputs = [
      libbsd
      libmnl
      numactl
      rdma-core
    ];

    dontStrip = true;
    enableParallelBuilding = true;

    patches = [
      ./dpdk.patch
      ./dpdk2.patch
    ];

    configurePhase = ''
      sed -i 's/kernel//g' GNUmakefile
      sed -i 's/CONFIG_RTE_LIBRTE_MLX5_PMD=.*/CONFIG_RTE_LIBRTE_MLX5_PMD=y/g' config/common_base
      sed -i 's/CONFIG_RTE_LIBRTE_MLX5_DLOPEN_DEPS=.*/CONFIG_RTE_LIBRTE_MLX5_DLOPEN_DEPS=n/g' config/common_base
      make config T=x86_64-native-linuxapp-gcc
      sed -i 's/CONFIG_RTE_MACHINE=.*/CONFIG_RTE_MACHINE="${machine}"/g' build/.config
      sed -i 's/CONFIG_RTE_EAL_IGB_UIO=.*/CONFIG_RTE_EAL_IGB_UIO=n/g' build/.config
      sed -i 's/CONFIG_RTE_KNI_KMOD=.*/CONFIG_RTE_KNI_KMOD=n/g' build/.config
    '';

    buildPhase = "true";

    installPhase = ''
      make -j$NIX_BUILD_CORES install T=x86_64-native-linuxapp-gcc DESTDIR=$out
    '';
  };

in

stdenv.mkDerivation rec {
  inherit pname src;
  version = "2.1p1";

  passthru = {
    inherit dpdk;
  };

  nativeBuildInputs = [
    autoconf
    automake
    bc
    pkg-config
  ];

  buildInputs = [
    dpdk
    gmp
    numactl
  ];

  dontStrip = true;

  patches = [ ./my.patch ];

  postPatch = ''
    sed -i 's@-Werror@@g' mtcp/src/Makefile.in
    sed -i 's@apps/example@@g' Makefile.in
    sed -i 's@apps/example@@g' Makefile.am
    rm aclocal.m4
  '';

  RTE_SDK = "${dpdk}/share/dpdk";
  RTE_TARGET = "x86_64-native-linuxapp-gcc";

  enableParallelBuilding = true;

  configureFlags = [
    "--disable-lro"
    "--with-dpdk-lib=${dpdk}"
  ] ++ (lib.optional disableTxHwCksum "--disable-hwcsum");

  installPhase = ''
    mkdir -p $out
    cp -r mtcp/include $out/include
    cp -r mtcp/lib $out/lib
  '';
}
