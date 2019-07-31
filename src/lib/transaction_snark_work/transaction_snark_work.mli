module Make (Ledger_proof : sig
  type t [@@deriving sexp, bin_io, to_yojson]
end) :
  Coda_intf.Transaction_snark_work_intf
  with type ledger_proof := Ledger_proof.t

include
  Coda_intf.Transaction_snark_work_intf
  with type ledger_proof := Ledger_proof.t
