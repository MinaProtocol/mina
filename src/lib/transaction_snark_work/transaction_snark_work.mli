open Signature_lib

module Make (Ledger_proof : sig
  type t [@@deriving sexp, bin_io]
end) :
  Protocols.Coda_pow.Transaction_snark_work_intf
  with type proof := Ledger_proof.t
   and type statement := Transaction_snark.Statement.t
   and type public_key := Public_key.Compressed.t

include
  Protocols.Coda_pow.Transaction_snark_work_intf
  with type proof := Ledger_proof.t
   and type statement := Transaction_snark.Statement.t
   and type public_key := Public_key.Compressed.t
