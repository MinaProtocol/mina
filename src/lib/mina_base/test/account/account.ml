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

     let%test_unit "Minimum balance never changes before the cliff time." =
       Quickcheck.test
         (let open Quickcheck.Generator.Let_syntax in
          let%bind timing = Account.gen_timing Balance.max_int in
          let max_global_slot =
            Global_slot.(sub timing.cliff_time (of_int 1))
            |> Option.value_exn
          in
          let%map global_slot = Global_slot.(gen_incl zero max_global_slot) in
          (timing, global_slot))
         ~f:(fun (timing, global_slot) ->
           [%test_eq: Balance.t]
             timing.initial_minimum_balance
             (min_balance_at_slot timing ~global_slot))

     let%test_unit "Cliff amount is immediately released at cliff_time." =
       Quickcheck.test
          (Account.gen_timing Balance.max_int) 
          ~f:(fun timing ->
            let min_balance =
              Balance.(timing.initial_minimum_balance - timing.cliff_amount)
              |> Option.value_exn
            in
           [%test_eq: Balance.t]
             min_balance
             (min_balance_at_slot timing ~global_slot:timing.cliff_time))

     let%test_unit "Minimum balance never increases over time." =
       Quickcheck.test
         (let open Quickcheck.Generator.Let_syntax in
          let%bind timing = Account.gen_timing Balance.max_int in
          let%bind slot1 = Global_slot.gen in
          let%map slot2 = Global_slot.(gen_incl slot1 max_value) in
          (timing, slot1, slot2))
         ~f:(fun (timing, slot1, slot2) ->
           [%test_pred: Balance.t * Balance.t]
             (Tuple.T2.uncurry Balance.(>=))
             (min_balance_at_slot timing ~global_slot:slot1, min_balance_at_slot timing ~global_slot:slot2))
  end)
