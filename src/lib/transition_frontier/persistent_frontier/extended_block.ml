open Core_kernel

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  (* TODO: user commands are stored twice in [block] and
     in [update_coinbase_stack_and_get_data_result] fields,
     consider optimizing. *)
  module V1 = struct
    type t =
      { block : Mina_block.Stable.V2.t
      ; update_coinbase_stack_and_get_data_result :
          Staged_ledger.Update_coinbase_stack_and_get_data_result.Stable.V1.t
          option
      ; state_body_hash : Mina_base.State_body_hash.Stable.V1.t
      }

    let to_latest = Fn.id
  end
end]
