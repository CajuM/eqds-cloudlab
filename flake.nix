{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  inputs.nixos-shell.url = "github:Mic92/nixos-shell";
  inputs.nixos-shell.inputs.nixpkgs.follows = "nixpkgs";
  inputs.utils.url = "github:numtide/flake-utils";

  outputs =
    { self
    , nixpkgs
    , nixos-shell
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

          mkVM =
            num:
            nixpkgs.lib.makeOverridable nixpkgs.lib.nixosSystem {
              inherit system pkgs;

              modules = [
                ((import ./common/mkvm.nix) num)
                nixos-shell.nixosModules.nixos-shell
              ];
            };

          exp-vm1 = mkVM 1;
          exp-vm2 = mkVM 2;

          exp-shell = import ./common/shell.nix { inherit pkgs; };

        in
        {
          inherit exp-shell;

          exp-vm1 = exp-vm1.config.system.build.vm;
          exp-vm2 = exp-vm2.config.system.build.vm;
        }
      );
    };
}
