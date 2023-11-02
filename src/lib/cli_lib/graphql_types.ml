(*Types coresponding to the result of graphql queries*)

(*List of completed work from Graphql_queries.Snark_pool*)
module Completed_works = struct
  module Work = struct
    type t =
      { work_ids : int list
      ; fee : Currency.Fee.t
      ; prover : Signature_lib.Public_key.Compressed.t
      }
    [@@deriving yojson]
  end

  type t = Work.t list [@@deriving yojson]
end

(*List of work to be done from Graphql_queries.PendingSnarkWork*)
module Pending_snark_work = struct
  module Work = struct
    type t =
      { work_id : int
      ; fee_excess : Currency.Amount.Signed.t
      ; supply_increase : Currency.Amount.t
      ; source_first_pass_ledger_hash : Mina_base.Frozen_ledger_hash.t
      ; target_first_pass_ledger_hash : Mina_base.Frozen_ledger_hash.t
      ; source_second_pass_ledger_hash : Mina_base.Frozen_ledger_hash.t
      ; target_second_pass_ledger_hash : Mina_base.Frozen_ledger_hash.t
      }
    [@@deriving yojson]
  end

  type t = Work.t array array [@@deriving yojson]
end
