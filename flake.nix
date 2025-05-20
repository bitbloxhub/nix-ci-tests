{
  description = "Description for the project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    actions-nix.url = "github:nialov/actions.nix";
    actions-nix.inputs.nixpkgs.follows = "nixpkgs";

    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      actions-nix,
      self,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {

      systems = [
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      imports = [
        inputs.pre-commit-hooks.flakeModule
        inputs.actions-nix.flakeModules.default
      ];

      flake.actions-nix = {
        pre-commit.enable = false;
        defaults = {
          jobs = {
            timeout-minutes = 60;
            runs-on = "ubuntu-latest";
          };
        };
        workflows = {
          ".github/workflows/main.yaml" = (import ./default.nix).makeNixAction { flake = self; };
        };
      };

      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          lib,
          ...
        }:
        {
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              nixfmt-rfc-style
              nushell
              deno
            ];
          };
          checks = {
            check-a = pkgs.stdenv.mkDerivation {
              name = "check-a";
              src = ./.;
              doCheck = true;
              dontBuild = true;
              nativeBuildInputs = [ pkgs.bashhh ];
              checkPhase = ''
                patchShebangs *.sh
                if [[ "$(./a.sh)" == *a* ]]; then true; else echo "fail" && false; fi;
              '';
              installPhase = ''
                mkdir "$out"
              '';
            };
            check-b = pkgs.stdenv.mkDerivation {
              name = "check-b";
              src = ./.;
              doCheck = true;
              dontBuild = true;
              nativeBuildInputs = [ pkgs.bash ];
              checkPhase = ''
                patchShebangs *.sh
                if [[ "$(./b.sh)" == *b* ]]; then true; else echo "fail" && false; fi;
              '';
              installPhase = ''
                mkdir "$out"
              '';
            };
            check-c = pkgs.stdenv.mkDerivation {
              name = "check-c";
              src = ./.;
              doCheck = true;
              dontBuild = true;
              nativeBuildInputs = [ pkgs.bash ];
              checkPhase = ''
                patchShebangs *.sh
                if [[ "$(./c.sh)" == *c* ]]; then true; else echo "fail" && false; fi;
              '';
              installPhase = ''
                mkdir "$out"
              '';
            };
          };
        };
    };
}
