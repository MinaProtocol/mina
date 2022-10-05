let commit_id = "[UNKNOWN]"

let commit_id_short = "[UNKNOWN]"

let branch = "[UNKNOWN]"

let commit_date = "1970-01-01T00:00:00+00:00"

let marlin_commit_id = "[UNKNOWN]"

let marlin_commit_id_short = "[UNKNOWN]"

let marlin_commit_date = "1970-01-01T00:00:00+00:00"

let print_version () =
  Core_kernel.printf "Commit %s on branch %s\n%!" commit_id branch
