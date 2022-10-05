let commit_id = Unix.getenv "MINA_COMMIT_SHA1"

let commit_id_short = String.sub commit_id 0 7

let branch = Unix.getenv "MINA_BRANCH"

let commit_date = Unix.getenv "MINA_COMMIT_DATE"

let marlin_commit_id = "[UNKNOWN]"

let marlin_commit_id_short = "[UNKNOWN]"

let marlin_commit_date = "1970-01-01T00:00:00+00:00"

let print_version () =
  Core_kernel.printf "Commit %s on branch %s\n%!" commit_id branch
