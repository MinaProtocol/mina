(*Types coresponding to the result of graphql queries*)

(*List of completed work from Graphql_queries.Snark_pool*)
module Completed_works = struct
  module Work = struct
    type t =
      { work_ids: int list
      ; fee: Currency.Fee.Stable.V1.t
      ; prover: Signature_lib.Public_key.Compressed.t }
    [@@deriving yojson]
  end

  type t = Work.t list [@@deriving yojson]
end

(*List of work to be done from Graphql_queries.PendingSnarkWork*)
module Pending_snark_work = struct
  module Work = struct
    type t =
      { work_id: int
      ; fee_excess: Currency.Fee.Signed.Stable.V1.t
      ; supply_increase: Currency.Amount.Stable.V1.t
      ; source_ledger_hash: Coda_base.Frozen_ledger_hash.Stable.V1.t
      ; target_ledger_hash: Coda_base.Frozen_ledger_hash.Stable.V1.t }
    [@@deriving yojson]
  end

  type t = Work.t list list [@@deriving yojson]
end
