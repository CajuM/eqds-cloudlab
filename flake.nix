{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  inputs.utils.url = "github:numtide/flake-utils";

  outputs =
    { self
    , nixpkgs
    , utils
    }:
    let
      system = "x86_64-linux";
      machines = nixpkgs.lib.splitString "\n" (nixpkgs.lib.fileContents ./common/machines.txt);
      pkgs = import nixpkgs { inherit system; };

    in
    {
      devShells.${system}.default = import ./shell.nix { inherit pkgs; };

      legacyPackages.${system} = utils.lib.eachSystemMap machines (
        machine:
        let
          pkgs = import nixpkgs {
            inherit system;

            overlays = [
              (self: super: { inherit machine; })
              (self: super: { disableTxHwCksum = false; })
              (self: super: { disableRxCksum = true; })
              (self: super: { ndpipGrantsEnable = false; })
              (self: super: {
                extraCFlags = [
                  "-g"
                  "-O3"
                  "-march=${machine}"
                ];
              })
              (import ./overlays/mystdenv-overlay.nix)
              (import ./overlays/dpdk-overlay.nix)
              (import ./overlays/my-kernel-overlay.nix)
              (import ./overlays/pkgs-overlay.nix)
            ];
          };

          exp-shell = import ./common/shell.nix { inherit pkgs; };

        in
        {
          inherit exp-shell;
          devShell.default = import ./shell.nix;
        }
      );
    };
}
