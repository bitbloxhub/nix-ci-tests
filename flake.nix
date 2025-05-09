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
          ".github/workflows/main.yaml" = {
            jobs = {
              fast-build = {
                steps = [
                  {
                    uses = "actions/checkout@v4";
                  }
                  {
                    uses = "DeterminateSystems/nix-installer-action@main";
                    "with" = {
                      source-url = "https://install.lix.systems/lix/lix-installer-\${{ fromJSON('{\"X64\":\"x86_64\",\"X86\":\"i686\",\"ARM64\":\"aarch64\",\"ARM\":\"armv7l\"}')[runner.arch] }}-\${{ fromJSON('{\"Linux\":\"linux\",\"macOS\":\"darwin\",\"Windows\":\"windows\"}')[runner.os] }}";
                      logger = "pretty";
                      diagnostic-endpoint = "";
                    };
                  }
                  {
                    name = "chown store";
                    run = "sudo chown -R $USER:$USER /nix/ && ls -la /nix/store/ /nix";
                  }
                  {
                    uses = "nix-community/cache-nix-action@v6";
                    "with" = {
                      primary-key = "nix-\${{ runner.os }}-\${{ hashFiles('**/*.nix', '**/flake.lock') }}";
                      restore-prefixes-first-match = "nix-\${{ runner.os }}";
                      gc-max-store-size-linux = "1073741824";
                      purge = true;
                      purge-prefixes = "nix-\${{ runner.os }}-";
                      purge-created = 0;
                      purge-primary-key = "never";
                    };
                  }
                  {
                    name = "chown store";
                    run = "sudo chown -R root:root /nix/ && sudo chown root:nixbld /nix/store";
                  }
                  {
                    name = "check flake";
                    run = "nix -Lv flake check";
                  }
                ];
              };
            };
          };
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
            ];
          };
          checks = {
            check-a = pkgs.stdenv.mkDerivation {
              name = "check-a";
              src = ./.;
              doCheck = true;
              dontBuild = true;
              nativeBuildInputs = [ pkgs.bash ];
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
                if [[ "$(./c.sh)" == *b* ]]; then true; else echo "fail" && false; fi;
              '';
              installPhase = ''
                mkdir "$out"
              '';
            };
          };
        };
    };
}
