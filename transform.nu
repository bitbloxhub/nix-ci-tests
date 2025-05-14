#!/usr/bin/env nu

def main (file: string) {
  "a" | inspect
  open $file
  | get results
  | each {|status|
    match $status.type {
        "EVAL" => (if ($status.success) {
          $status
        } else {
          $status.attr | inspect
          let eval_err = (do -i
            {TERM=xterm-256color script -efq -c $"nix eval --show-trace \".#checks.($status.attr)\"" e+o>|}
          )
          rm ./typescript
          $status | update error $eval_err
        })
        "BUILD" => {
          $status.attr | inspect
          let build_log = (do -i
            {TERM=xterm-256color script -efq -c $"nix log \".#checks.($status.attr)\"" e+o>|}
          )
          rm ./typescript
          $status | update error $build_log
        }
        _ => $status
      }
    }
  | to json
  | save -f result_parsed.json
}
