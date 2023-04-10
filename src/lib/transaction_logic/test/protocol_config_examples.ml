open Currency
open Mina_base
open Mina_numbers

let epoch_seed = Epoch_seed.of_decimal_string "500"

let epoch_data =
  Epoch_data.Poly.
    { ledger =
        Epoch_ledger.Poly.
          { hash = Frozen_ledger_hash.empty_hash
          ; total_currency = Amount.of_mina_int_exn 10_000_000
          }
    ; seed = epoch_seed
    ; start_checkpoint = State_hash.dummy
    ; lock_checkpoint = State_hash.dummy
    ; epoch_length = Length.of_int 20
    }

let protocol_state : Zkapp_precondition.Protocol_state.View.t =
  Zkapp_precondition.Protocol_state.Poly.
    { snarked_ledger_hash = Frozen_ledger_hash.empty_hash
    ; blockchain_length = Length.of_int 119
    ; min_window_density = Length.of_int 10
    ; last_vrf_output = ()
    ; total_currency = Amount.of_mina_int_exn 10
    ; global_slot_since_genesis = Global_slot.of_int 120
    ; staking_epoch_data = epoch_data
    ; next_epoch_data = epoch_data
    }

let constraint_constants =
  { Genesis_constants.Constraint_constants.for_unit_tests with
    account_creation_fee = Fee.of_mina_int_exn 1
  }
