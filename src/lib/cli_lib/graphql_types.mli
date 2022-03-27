module Completed_works : sig
  module Work : sig
    type t =
      { work_ids : int list
      ; fee : Currency.Fee.t
      ; prover : Signature_lib.Public_key.Compressed.t
      }

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
  end

  type t = Work.t list

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
end

module Pending_snark_work : sig
  module Work : sig
    type t =
      { work_id : int
      ; fee_excess : Currency.Fee.Signed.t
      ; supply_increase : Currency.Amount.t
      ; source_ledger_hash : Mina_base.Frozen_ledger_hash.t
      ; target_ledger_hash : Mina_base.Frozen_ledger_hash.t
      }

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
  end

  type t = Work.t array array

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
end
