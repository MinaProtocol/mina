(*Types coresponding to the result of graphql queries*)

(*List of completed work from Graphql_queries.Snark_pool*)
module Completed_works = struct
  module Work = struct
    type t =
      { work_ids: int list
      ; fee: Currency.Fee.t
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
      ; fee_excess: Currency.Fee.Signed.t
      ; supply_increase: Currency.Amount.t
      ; source_ledger_hash: Coda_base.Frozen_ledger_hash.t
      ; target_ledger_hash: Coda_base.Frozen_ledger_hash.t }
    [@@deriving yojson]
  end

  type t = Work.t array array [@@deriving yojson]
end

module Coda_constants = struct
  module UInt32 = struct
    include Unsigned.UInt32

    let to_yojson t = `String (to_string t)
  end

  module UInt64 = struct
    include Unsigned.UInt64

    let to_yojson t = `String (to_string t)
  end

  type t =
    { genesis_timestamp: string
    ; k: UInt32.t
    ; coinbase: UInt64.t
    ; block_window_duration_ms: UInt64.t
    ; delta: UInt32.t
    ; c: UInt32.t
    ; inactivity_ms: UInt64.t
    ; sub_windows_per_window: UInt32.t
    ; slots_per_sub_window: UInt32.t
    ; slots_per_window: UInt32.t
    ; slots_per_epoch: UInt32.t }
  [@@deriving to_yojson]
end
