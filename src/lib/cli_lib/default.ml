(* Default values for cli flags *)
(* A payment requires 2 SNARKS, so this should always >= 2x the snark fee. *)
let transaction_fee = Currency.Fee.of_int 5_000_000_000

(*Fee for a snark bundle*)
let snark_worker_fee = Currency.Fee.of_int 1_000_000_000

let work_reassignment_wait = 420000

let conf_dir_name = ".coda-config"
