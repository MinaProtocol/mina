let commit_id = Unix.getenv "MINA_COMMIT_SHA1"

let commit_id_short = String.sub commit_id 0 7

let print_version () = Core_kernel.printf "Commit %s\n%!" commit_id
