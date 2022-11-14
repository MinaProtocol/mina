open Utils

module Types : sig
  module type S = sig
    module Body_reference : sig
      module V1 : sig
        type t = Blake2.Stable.V1.t
      end
    end

    module Data : sig
      module Consensus_state : sig
        module Value : V1S0
      end
    end
  end
end

module type Concrete = sig
  module Body_reference : sig
    module V1 : sig
      type t = Blake2.Stable.V1.t
    end
  end

  module Data : sig
    module Epoch_ledger : sig
      include module type of Mina_base.Epoch_ledger
    end

    module Epoch_data : sig
      module Staking_value_versioned : sig
        module Value : sig
          module V1 : sig
            type t =
              ( Epoch_ledger.Value.V1.t
              , Mina_base.Epoch_seed.V1.t
              , Data_hash_lib.State_hash.V1.t
              , Data_hash_lib.State_hash.V1.t
              , Mina_numbers.Length.V1.t )
              Mina_base.Epoch_data.Poly.V1.t
          end
        end
      end

      module Next_value_versioned : sig
        module Value : sig
          module V1 : sig
            type t =
              ( Epoch_ledger.Value.V1.t
              , Mina_base.Epoch_seed.V1.t
              , Data_hash_lib.State_hash.V1.t
              , Data_hash_lib.State_hash.V1.t
              , Mina_numbers.Length.V1.t )
              Mina_base.Epoch_data.Poly.V1.t
          end
        end
      end
    end

    module Consensus_state : sig
      module Poly : sig
        module V1 : sig
          type ( 'length
               , 'vrf_output
               , 'amount
               , 'global_slot
               , 'global_slot_since_genesis
               , 'staking_epoch_data
               , 'next_epoch_data
               , 'bool
               , 'pk )
               t =
            { blockchain_length : 'length
            ; epoch_count : 'length
            ; min_window_density : 'length
            ; sub_window_densities : 'length list
            ; last_vrf_output : 'vrf_output
            ; total_currency : 'amount
            ; curr_global_slot : 'global_slot
            ; global_slot_since_genesis : 'global_slot_since_genesis
            ; staking_epoch_data : 'staking_epoch_data
            ; next_epoch_data : 'next_epoch_data
            ; has_ancestor_in_same_checkpoint_window : 'bool
            ; block_stake_winner : 'pk
            ; block_creator : 'pk
            ; coinbase_receiver : 'pk
            ; supercharge_coinbase : 'bool
            }
        end
      end

      module Value : sig
        module V1 : sig
          type t =
            ( Mina_numbers.Length.V1.t
            , Consensus_vrf.Output.Truncated.V1.t
            , Currency.Amount.V1.t
            , Consensus_global_slot.V1.t
            , Mina_numbers.Global_slot.V1.t
            , Epoch_data.Staking_value_versioned.Value.V1.t
            , Epoch_data.Next_value_versioned.Value.V1.t
            , bool
            , Public_key.Compressed.V1.t )
            Poly.V1.t
        end
      end
    end
  end
end

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include
  Types.S with module Body_reference = M.Body_reference and module Data = M.Data
