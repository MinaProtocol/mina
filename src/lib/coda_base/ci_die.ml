open Core_kernel

(** exit 1 if CODA_CI_DIE_IF_KEYS_OUTDATED=true *)
let skip_key_generation () =
  if
    Option.equal String.equal
      (Sys.getenv_opt "CODA_CI_DIE_IF_KEYS_OUTDATED")
      (Some "true")
  then (
    eprintf
      "error: dying because CI says we shouldn't be generating these keys\n" ;
    exit 1 )
  else ()
