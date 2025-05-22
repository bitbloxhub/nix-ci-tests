{
  makeNixAction =
    {
      useLix ? false,
      shouldInstall ? true,
      preBuild ? [ ],
      postUpload ? [ ],
      runs-on ? "ubuntu-latest",
      arch ? "x86_64-linux",
      workflowName ? "Nix ${arch}",
      flake,
    }:
    let
      sourceUrl =
        if (useLix) then
          "https://install.lix.systems/lix/lix-installer-\${{ fromJSON('{\"X64\":\"x86_64\",\"X86\":\"i686\",\"ARM64\":\"aarch64\",\"ARM\":\"armv7l\"}')[runner.arch] }}-\${{ fromJSON('{\"Linux\":\"linux\",\"macOS\":\"darwin\",\"Windows\":\"windows\"}')[runner.os] }}"
        else
          null;
    in
    {
      name = workflowName;
      jobs = {
        fast-build = {
          steps =
            [
              {
                uses = "actions/checkout@v4";
              }
              {
                uses = "DeterminateSystems/nix-installer-action@main";
                "with" = {
                  determinate = false;
                  logger = "pretty";
                  diagnostic-endpoint = "";
                } // (if (sourceUrl != null) then { source-url = sourceUrl; } else { });
              }
            ]
            ++ preBuild
            ++ [
              {
                name = "nix-fast-build";
                run = "nix run nixpkgs#lixPackageSets.latest.nix-fast-build -- --no-nom --flake \".#checks.${arch}\" result.json || true";
              }
              {
                name = "transform";
                run = "nix shell nixpkgs#unixtools.script nixpkgs#nushell --command nu ./transform.nu result.json";
              }
              {
                name = "upload artifact";
                uses = "actions/upload-artifact@v4";
                "with" = {
                  name = "results";
                  path = ''
                    ./result_parsed.json
                    ./result-*
                  '';
                };
              }
            ]
            ++ postUpload;
        };
        download-artifact = {
          needs = [ "fast-build" ];
          steps = [
            {
              uses = "actions/checkout@v4";
            }
            {
              uses = "actions/download-artifact@v4";
              "with" = {
                path = "artifacts";
              };
            }
            {
              name = "ls";
              run = "ls artifacts/*";
            }
          ];
        };
      };
    };
}
