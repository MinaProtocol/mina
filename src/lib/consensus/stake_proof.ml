open Core
open Mina_base
open Signature_lib

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    type t =
      { delegator : Account.Index.Stable.V1.t
      ; delegator_pk : Public_key.Compressed.Stable.V1.t
      ; coinbase_receiver_pk : Public_key.Compressed.Stable.V1.t
      ; ledger : Mina_ledger.Sparse_ledger.Stable.V2.t
      ; producer_private_key : Private_key.Stable.V1.t
      ; producer_public_key : Public_key.Stable.V1.t
      }

    let to_latest = Fn.id
  end
end]

(* This is only the data that is necessary for creating the
   blockchain SNARK which is not otherwise available. So in
   particular it excludes the epoch and slot this stake proof
   is for.
*)
type t = Stable.Latest.t =
  { delegator : Account.Index.t
  ; delegator_pk : Public_key.Compressed.t
  ; coinbase_receiver_pk : Public_key.Compressed.t
  ; ledger : Mina_ledger.Sparse_ledger.t
  ; producer_private_key : Private_key.t
  ; producer_public_key : Public_key.t
  }
[@@deriving to_yojson, sexp]
