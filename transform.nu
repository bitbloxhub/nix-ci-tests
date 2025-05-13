#!/usr/bin/env nu

def main (file: string) {
  echo "a"
  open $file
  | get results
  | each {|status|
    match $status.type {
        "EVAL" => (if ($status.success) {
          $status
        } else {
          let eval_err = (do -i
            {faketty nix eval --show-trace $".#checks.($status.attr)" e+o>| cat}
          )
          $eval_err | inspect
          $status | update error $eval_err
        })
        "BUILD" => {
          let build_log = (do -i
            {faketty nix log $".#checks.($status.attr)" e+o>| cat}
          )
          $build_log | inspect
          $status | update error $build_log
        }
        _ => $status
      }
    }
  | to json
  | save -f $file
}
