module Make (Ledger_proof : sig
  type t [@@deriving sexp, to_yojson]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, bin_io, to_yojson, version]
      end

      module Latest = V1
    end
    with type V1.t = t

  val statement : t -> Transaction_snark.Statement.t
end) :
  Coda_intf.Transaction_snark_work_intf
  with type ledger_proof := Ledger_proof.t

include
  Coda_intf.Transaction_snark_work_intf
  with type ledger_proof := Ledger_proof.t
