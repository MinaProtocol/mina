module Update_coinbase_stack_and_get_data_result_or_commands : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      type t

      val to_latest : t -> t
    end
  end]
end

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t =
      { header : Mina_block.Header.Stable.V2.t
      ; diff :
          ( Transaction_snark_work.Stable.V2.t
          , unit )
          Staged_ledger_diff.Pre_diff_two.Stable.V2.t
          * ( Transaction_snark_work.Stable.V2.t
            , unit )
            Staged_ledger_diff.Pre_diff_one.Stable.V2.t
            option
      ; update_coinbase_stack_and_get_data_result :
          Update_coinbase_stack_and_get_data_result_or_commands.Stable.V1.t
      ; state_body_hash : Mina_base.State_body_hash.Stable.V1.t
      }

    val to_latest : t -> t
  end
end]

val update_coinbase_stack_and_get_data_result :
     Stable.Latest.t
  -> Staged_ledger.Update_coinbase_stack_and_get_data_result.Stable.Latest.t
     option

val to_block : Stable.Latest.t -> Mina_block.Stable.Latest.t

val take_hashes_from_witnesses :
     proof_cache_db:Proof_cache_tag.cache_db
  -> update_coinbase_stack_and_get_data_result:
       Staged_ledger.Update_coinbase_stack_and_get_data_result.t
  -> Mina_block.Stable.Latest.t
  -> Mina_block.t

val of_validated_block :
     ?update_coinbase_stack_and_get_data_result:
       Staged_ledger.Update_coinbase_stack_and_get_data_result.t
  -> ledger_depth:int
  -> Mina_block.Validated.t
  -> Stable.Latest.t
