{ fetchFromGitHub, python3Packages, ... }:

python3Packages.buildPythonApplication {
  name = "qemu-affinity";

  src = fetchFromGitHub {
    owner = "zegelin";
    repo = "qemu-affinity";
    rev = "master";
    sha256 = "sha256-SinMFjptX7kbJbdBOddaRRPkbRLjEBBn7pH6yHUTtGc=";
  };

  postPatch = ''
    sed -i 's/QEMU_COMM_RE.match/QEMU_COMM_RE.findall/g' qemu_affinity.py
  '';
}
