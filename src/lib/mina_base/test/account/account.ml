open Core_kernel
open Currency
open Mina_base
open Mina_numbers
open Unsigned

let gen_timing = Account.gen_timing Balance.max_int

let gen_timing_with_necessary_vesting =
  let open Quickcheck in
  let open Account.Timing.As_record in
  Account.gen_timing Balance.max_int
  |> Generator.filter ~f:(fun t ->
         let open Balance in
         t.initial_minimum_balance - t.cliff_amount
         |> Option.value_map ~default:false ~f:(fun to_vest -> to_vest > zero) )

let%test_module "Test account's timing." =
  ( module struct
    open Account.Timing.As_record

    let min_balance_at_slot (t : Account.Timing.as_record) =
      Account.min_balance_at_slot
        ~initial_minimum_balance:t.initial_minimum_balance
        ~cliff_amount:t.cliff_amount ~cliff_time:t.cliff_time
        ~vesting_period:t.vesting_period ~vesting_increment:t.vesting_increment

    let incr_bal_between (t : Account.Timing.as_record) ~start_slot ~end_slot =
      Account.incremental_balance_between_slots ~cliff_time:t.cliff_time
        ~cliff_amount:t.cliff_amount ~vesting_period:t.vesting_period
        ~vesting_increment:t.vesting_increment
        ~initial_minimum_balance:t.initial_minimum_balance ~start_slot ~end_slot
      |> Balance.of_uint64

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
        let%bind timing = gen_timing in
        let max_global_slot =
          Global_slot.(sub timing.cliff_time (of_int 1)) |> Option.value_exn
        in
        let%map global_slot = Global_slot.(gen_incl zero max_global_slot) in
        (timing, global_slot))
        ~f:(fun (timing, global_slot) ->
          [%test_eq: Balance.t] timing.initial_minimum_balance
            (min_balance_at_slot timing ~global_slot) )

    let%test_unit "Cliff amount is immediately released at cliff_time." =
      Quickcheck.test gen_timing ~f:(fun timing ->
          let min_balance =
            Balance.(timing.initial_minimum_balance - timing.cliff_amount)
            |> Option.value_exn
          in
          [%test_eq: Balance.t] min_balance
            (min_balance_at_slot timing ~global_slot:timing.cliff_time) )

    let%test_unit "Minimum balance never increases over time." =
      Quickcheck.test
        (let open Quickcheck.Generator.Let_syntax in
        let%bind timing = gen_timing in
        let%bind slot1 = Global_slot.gen in
        let%map slot2 = Global_slot.(gen_incl slot1 max_value) in
        (timing, slot1, slot2))
        ~f:(fun (timing, slot1, slot2) ->
          [%test_pred: Balance.t * Balance.t]
            (Tuple.T2.uncurry Balance.( >= ))
            ( min_balance_at_slot timing ~global_slot:slot1
            , min_balance_at_slot timing ~global_slot:slot2 ) )

    let%test_unit "Final vesting slot is the first when minimum balance is 0." =
      Quickcheck.test gen_timing ~f:(fun timing_rec ->
          let timing = Account.Timing.of_record timing_rec in
          let vesting_final_slot = Account.timing_final_vesting_slot timing in
          [%test_eq: Balance.t] Balance.zero
            (min_balance_at_slot timing_rec ~global_slot:vesting_final_slot) ;
          let one_slot_prior =
            Global_slot.(sub vesting_final_slot (of_int 1))
            |> Option.value ~default:Global_slot.zero
          in
          [%test_pred: Balance.t]
            Balance.(( < ) zero)
            (min_balance_at_slot timing_rec ~global_slot:one_slot_prior) )

    let%test_unit "Every vesting period, minimum balance decreases by vesting \
                   increment." =
      Quickcheck.test
        (let open Quickcheck in
        let open Generator.Let_syntax in
        (* The amount to be vested after the cliff time must be greater than zero
           or else there is no vesting at all. *)
        let%bind timing_rec = gen_timing_with_necessary_vesting in
        let timing = Account.Timing.of_record timing_rec in
        let vesting_end = Account.timing_final_vesting_slot timing in
        (* Global_slot addition may overflow, so we need to make sure it won't happen. *)
        let max_slot =
          let open Global_slot in
          sub max_value timing_rec.vesting_period
          |> Option.value_map ~default:vesting_end ~f:(min vesting_end)
        in
        let%map global_slot =
          Global_slot.gen_incl timing_rec.cliff_time max_slot
        in
        (timing, timing_rec, global_slot))
        ~f:(fun (timing, timing_rec, global_slot) ->
          let vesting_period_later =
            Global_slot.add global_slot timing_rec.vesting_period
          in
          let min_bal_at_slot = min_balance_at_slot timing_rec ~global_slot in
          let min_bal_later =
            min_balance_at_slot timing_rec ~global_slot:vesting_period_later
          in
          [%test_eq: Balance.t] min_bal_later
            Balance.(
              Option.value ~default:zero
              @@ (min_bal_at_slot - timing_rec.vesting_increment)) )

    let%test_unit "Incremental balance between slots before cliff is 0." =
      Quickcheck.test
        (let open Quickcheck.Generator.Let_syntax in
        let%bind timing = gen_timing in
        let max_slot =
          Global_slot.(sub timing.cliff_time (of_int 1))
          |> Option.value ~default:Global_slot.zero
        in
        let%bind slot1 = Global_slot.(gen_incl zero max_slot) in
        let%map slot2 = Global_slot.gen_incl slot1 max_slot in
        (timing, slot1, slot2))
        ~f:(fun (timing, start_slot, end_slot) ->
          [%test_eq: Balance.t] Balance.zero
            (incr_bal_between timing ~start_slot ~end_slot) )

    let%test_unit "Incremental balance between slots after vesting finished is \
                   0." =
      Quickcheck.test
        (let open Quickcheck.Generator.Let_syntax in
        let%bind timing = gen_timing in
        let vesting_end =
          Account.timing_final_vesting_slot (Account.Timing.of_record timing)
        in
        let%bind slot1 = Global_slot.(gen_incl vesting_end max_value) in
        let%map slot2 = Global_slot.(gen_incl slot1 max_value) in
        (timing, slot1, slot2))
        ~f:(fun (timing, start_slot, end_slot) ->
          [%test_eq: Balance.t] Balance.zero
            (incr_bal_between timing ~start_slot ~end_slot) )

    let%test_unit "Incremental balance where end is before start is 0." =
      Quickcheck.test
        (let open Quickcheck.Generator.Let_syntax in
        let%bind timing = gen_timing in
        let%bind slot1 = Global_slot.gen in
        let%map slot2 = Global_slot.(gen_incl zero slot1) in
        (timing, slot1, slot2))
        ~f:(fun (timing, start_slot, end_slot) ->
          [%test_eq: Balance.t] Balance.zero
            (incr_bal_between timing ~start_slot ~end_slot) )

    let%test_unit "Incremental balance during vesting is a multiply of \
                   vesting_increment." =
      Quickcheck.test
        (let open Quickcheck in
        let open Generator.Let_syntax in
        let%bind timing =
          Generator.filter gen_timing_with_necessary_vesting ~f:(fun t ->
              Global_slot.(t.vesting_period > of_int 1) )
        in
        let min_slot = Global_slot.(add timing.cliff_time (of_int 1)) in
        let max_slot =
          let open Global_slot in
          sub
            Account.(timing_final_vesting_slot @@ Timing.of_record timing)
            (of_int 1)
          |> Option.value ~default:zero
        in
        let%bind slot1 = Global_slot.gen_incl min_slot max_slot in
        let%map slot2 = Global_slot.gen_incl slot1 max_slot in
        (timing, slot1, slot2))
        ~f:(fun (timing, start_slot, end_slot) ->
          let open UInt64 in
          [%test_eq: int] 0
            ( to_int
            @@ rem
                 ( Balance.to_uint64
                 @@ incr_bal_between timing ~start_slot ~end_slot )
                 (Amount.to_uint64 timing.vesting_increment) ) )

    let%test_unit "Liquid balance in untimed account always equal to balance." =
      Quickcheck.test
        (let open Quickcheck.Generator.Let_syntax in
        let%bind account = Account.gen in
        let%map global_slot = Global_slot.gen in
        (account, global_slot))
        ~f:(fun (account, global_slot) ->
          [%test_eq: Balance.t] account.balance
            Account.(liquid_balance_at_slot account ~global_slot) )

    let%test_unit "Liquid balance is balance - minimum balance at given slot." =
      Quickcheck.test
        (let open Quickcheck.Generator.Let_syntax in
        let%bind account = Account.gen_timed in
        let%map global_slot = Global_slot.gen in
        (account, global_slot))
        ~f:(fun (account, global_slot) ->
          let minimum_balance =
            min_balance_at_slot
              Account.Timing.(to_record account.timing)
              ~global_slot
          in
          [%test_eq: Balance.t]
            Balance.(
              account.balance - to_amount minimum_balance
              |> Option.value ~default:zero)
            Account.(liquid_balance_at_slot account ~global_slot) )
  end )
