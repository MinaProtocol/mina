(* Default fees applied *)
(* A payment requires 2 SNARKS, so this should always >= 2x the snark fee. *)
let default_transaction = Currency.Fee.of_int 2

let default_snark_worker = Currency.Fee.of_int 1
