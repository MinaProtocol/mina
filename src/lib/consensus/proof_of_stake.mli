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

    val global_slot : t -> Coda_numbers.Global_slot.t
  end

  module Consensus_state : sig
    include
      module type of Data.Consensus_state
      with type Value.Stable.V1.t = Data.Consensus_state.Value.Stable.V1.t

    val global_slot : Value.t -> Global_slot.t

    val total_currency : Value.t -> Currency.Amount.t

    val min_window_density : Value.t -> Coda_numbers.Length.t

    val staking_epoch_data : Value.t -> Coda_base.Epoch_data.Value.t

    val next_epoch_data : Value.t -> Coda_base.Epoch_data.Value.t

    (* unsafe modules for creating dummy states when doing vrf evaluations *)
    (* TODO: refactor code so that [Hooks.next_proposal] does not require a full [Consensus_state] *)
    module Unsafe : sig
      val dummy_advance :
           Value.t
        -> ?increase_epoch_count:bool
        -> new_global_slot:Global_slot.t
        -> Value.t
    end
  end
end
