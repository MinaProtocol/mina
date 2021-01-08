include Intf.S

(** Exported provides an easy way to publicly expose certain internal details
 *  of proof of stake which can be used when referring directly to the
 *  [Consensus.Proof_of_stake] consensus implementation rather than the default
 *  [Consensus] implementation
 *)
module Exported : sig
  module Global_slot = Global_slot

  module Block_data : sig
    include module type of Data.Block_data with type t = Data.Block_data.t
  end

  module Consensus_state : sig
    include
      module type of Data.Consensus_state
      with type Value.Stable.V1.t = Data.Consensus_state.Value.Stable.V1.t
       and type var = Data.Consensus_state.var

    val global_slot : Value.t -> Global_slot.t

    val total_currency : Value.t -> Currency.Amount.t

    val min_window_density : Value.t -> Mina_numbers.Length.t

    val staking_epoch_data : Value.t -> Mina_base.Epoch_data.Value.t

    val next_epoch_data : Value.t -> Mina_base.Epoch_data.Value.t

    (* TODO: refactor code so that [Hooks.next_proposal] does not require a full [Consensus_state] *)
    module Unsafe : sig
      (* for creating dummy states when doing vrf evaluations *)
      val dummy_advance :
           Value.t
        -> ?increase_epoch_count:bool
        -> new_global_slot:Global_slot.t
        -> Value.t

      (* for any code that needs to built a [Consensus_state] *)
      val create_value :
           [< `I_have_an_excellent_reason_to_call_this]
        -> blockchain_length:Mina_numbers.Length.t
        -> epoch_count:Mina_numbers.Length.t
        -> min_window_density:Mina_numbers.Length.t
        -> sub_window_densities:Mina_numbers.Length.t list
        -> last_vrf_output:string
        -> total_currency:Currency.Amount.t
        -> curr_global_slot:Global_slot.t
        -> global_slot_since_genesis:Mina_numbers.Global_slot.t
        -> staking_epoch_data:Mina_base.Epoch_data.Value.t
        -> next_epoch_data:Mina_base.Epoch_data.Value.t
        -> has_ancestor_in_same_checkpoint_window:bool
        -> block_stake_winner:Signature_lib.Public_key.Compressed.t
        -> block_creator:Signature_lib.Public_key.Compressed.t
        -> coinbase_receiver:Signature_lib.Public_key.Compressed.t
        -> supercharge_coinbase:bool
        -> Data.Consensus_state.Value.t
    end
  end
end
