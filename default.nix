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
      sourceUrl = if (useLix) then "https://install.lix.systems/lix/lix-installer-${arch}" else null;
    in
    {
      name = workflowName;
      jobs =
        {
          fast-build = {
            steps =
              [
                {
                  uses = "actions/checkout@v4";
                }
              ]
              ++ (
                if (shouldInstall) then
                  [
                    {
                      uses = "determinatesystems/nix-installer-action@main";
                      "with" = {
                        determinate = false;
                        logger = "pretty";
                        diagnostic-endpoint = "";
                      } // (if (sourceUrl != null) then { source-url = sourceUrl; } else { });
                    }
                  ]
                else
                  [ ]
              )
              ++ preBuild
              ++ [
                {
                  name = "nix-fast-build";
                  run = "nix run nixpkgs#lixPackageSets.latest.nix-fast-build -- --no-nom --flake \".#checks.${arch}\" --result-file result.json || true";
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
        }
        // builtins.listToAttrs (
          builtins.map (attr: {
            name = attr;
            value = {
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
                  uses = "hustcer/setup-nu@v3";
                  "with" = {
                    check-latest = true;
                  };
                }
                {
                  name = "report";
                  run = "nu ./report.nu artifacts/results/result_parsed.json ${attr}";
                }
              ];
            };
          }) (builtins.attrNames flake.checks.${arch})
        );
    };
}
