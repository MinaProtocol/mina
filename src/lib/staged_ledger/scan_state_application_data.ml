open Core_kernel
open Mina_base

[%%versioned
module Stable = struct
  module V1 = struct
    (* Data for loading the staged ledger *)
    type t =
      { is_new_stack : bool
      ; stack_update :
          Pending_coinbase.Stack_versioned.Stable.V1.t One_or_two.Stable.V1.t
          option
      ; first_pass_ledger_end : Frozen_ledger_hash.Stable.V1.t
      ; tagged_works :
          Transaction_snark_scan_state.Ledger_proof_with_sok_message.Tagged
          .Stable
          .V1
          .t
          list
      ; tagged_witnesses :
          Transaction_snark_scan_state.Transaction_with_witness.Tagged.Stable.V1
          .t
          list
      }

    let to_latest = Fn.id
  end
end]
