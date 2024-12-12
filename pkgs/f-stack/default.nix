{ stdenv
, lib
, fetchFromGitHub
, breakpointHook
, pkg-config
, dpdk
, jansson
, libelf
, libnl
, libpcap
, numactl
, openssl
, zlib
, disableTxHwCksum
}:

let
  pname = "f-stack";
  version = "1.23";

  src = fetchFromGitHub {
    owner = "F-Stack";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-5JBGTkWOz0q887V5xGkhaA3V1LuYUGLwUd3/mpHZYTA=";
  };

  dpdk-f-stack = dpdk.overrideAttrs (old: {
    version = "${pname}-${version}";
    inherit src;

    mesonFlags = (lib.lists.remove "-Denable_apps=dumpcap,pdump,proc-info,test-pmd" old.mesonFlags) ++ [
      "-Ddisable_drivers=common/cnxk,net/tap,event/octeontx"
    ];

    prePatch = ''
      cd dpdk
      rm Makefile
    '';
  });

in
stdenv.mkDerivation rec {
  inherit pname version src;

  passthru = {
    dpdk = dpdk-f-stack;
  };

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    dpdk-f-stack
    jansson
    libelf
    libnl
    libpcap
    numactl
    openssl
    zlib
  ];

  dontStrip = true;

  patches = [ ./my.patch ];

  postPatch = ''
    sed -i 's/-Werror//g' mk/kern.pre.mk
    sed -i 's/-O2//g' mk/kern.pre.mk
    pushd $PWD
    cd lib
    sed -i 's/-Werror//g' Makefile
    sed -i 's/-O2//g' Makefile
    sed -i 's/^PREFIX=.*/PREFIX?=/g' Makefile
    sed -i 's@^PREFIX_INCLUDE=.*@PREFIX_INCLUDE=$(PREFIX)/include@g' Makefile
    sed -i 's@^PREFIX_BIN=.*@PREFIX_BIN=$(PREFIX)/bin@g' Makefile
    sed -i 's@.*F-STACK_CONF.*@@g' Makefile
    popd

    pushd $PWD
    cd tools/compat
    sed -i 's/-Werror//g' Makefile
    popd
  '';

  buildPhase = ''
    pushd $PWD
    cd lib
    make -j$NIX_BUILD_CORES
    popd

    pushd $PWD
    cd tools/compat
    make -j$NIX_BUILD_CORES
    popd
  '';

  installPhase = ''
    mkdir -p "$out/bin"
    mkdir -p "$out/include/ffcompat"
    mkdir -p "$out/lib"

    pushd $PWD
    cd lib
    make install PREFIX=$out
    cp *.h $out/include
    popd

    pushd $PWD
    cd tools/compat
    cp libffcompat.a $out/lib/libffcompat.a
    cp -r include/* $out/include/ffcompat/
    cp *.h $out/include/ffcompat/
    popd
  '';
}
