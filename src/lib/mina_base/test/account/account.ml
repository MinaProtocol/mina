open Core_kernel
open Currency
open Mina_base
open Mina_numbers


let%test_module "Test account's timing." =
  (module struct
     open Account.Timing.As_record
     
     let min_balance_at_slot (t : Account.Timing.as_record) =
       Account.min_balance_at_slot
         ~initial_minimum_balance:t.initial_minimum_balance
         ~cliff_amount:t.cliff_amount
         ~cliff_time:t.cliff_time
         ~vesting_period:t.vesting_period
         ~vesting_increment:t.vesting_increment
     
    (* Test that the timed account generator only generates accounts that
       are completely vested before the largest possible slot, (2^32)-1. *)
    let%test_unit "Test fine-tuning of the account generation." =
      Quickcheck.test Account.gen_timed ~f:(fun account ->
          [%test_eq: Balance.t option] (Some Balance.zero)
            ( match account.timing with
            | Untimed ->
                None
            | Timed
                { initial_minimum_balance
                ; cliff_time
                ; cliff_amount
                ; vesting_period
                ; vesting_increment
                } ->
                let global_slot = Global_slot.max_value in
                Option.some
                @@ Account.min_balance_at_slot ~global_slot ~cliff_time
                     ~cliff_amount ~vesting_period ~vesting_increment
                     ~initial_minimum_balance ) )
  end)
