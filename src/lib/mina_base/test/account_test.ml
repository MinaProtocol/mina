(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^accounts$'
    Subject:    Test basic accounts.
 *)

open Core_kernel
open Currency
open Mina_base
open Mina_numbers
open Unsigned
open Account.Timing.As_record

let gen_timing = Account.gen_timing Balance.max_int

let min_balance_at_slot (t : Account.Timing.as_record) =
  Account.min_balance_at_slot ~initial_minimum_balance:t.initial_minimum_balance
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
let fine_tuning_of_the_account_generation () =
  Quickcheck.test Account.gen_timed ~f:(fun account ->
      try
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
              let global_slot = Global_slot_since_genesis.max_value in
              Option.some
              @@ Account.min_balance_at_slot ~global_slot ~cliff_time
                   ~cliff_amount ~vesting_period ~vesting_increment
                   ~initial_minimum_balance )
      with e ->
        Printf.printf "%s"
          (Sexp.to_string @@ Account.Timing.sexp_of_t account.timing) ;
        raise e )

let minimum_balance_never_changes_before_the_cliff_time () =
  Quickcheck.test
    (let open Quickcheck.Generator.Let_syntax in
    let%bind timing = gen_timing in
    let max_global_slot =
      Global_slot_since_genesis.(
        sub timing.cliff_time Global_slot_span.(of_int 1))
      |> Option.value_exn
    in
    let%map global_slot =
      Global_slot_since_genesis.(gen_incl zero max_global_slot)
    in
    (timing, global_slot))
    ~f:(fun (timing, global_slot) ->
      [%test_eq: Balance.t] timing.initial_minimum_balance
        (min_balance_at_slot timing ~global_slot) )

let cliff_amount_is_immediately_released_at_cliff_time () =
  Quickcheck.test gen_timing ~f:(fun timing ->
      let min_balance =
        Balance.(timing.initial_minimum_balance - timing.cliff_amount)
        |> Option.value_exn
      in
      [%test_eq: Balance.t] min_balance
        (min_balance_at_slot timing ~global_slot:timing.cliff_time) )

let minimum_balance_never_increases_over_time () =
  Quickcheck.test
    (let open Quickcheck.Generator.Let_syntax in
    let%bind timing = gen_timing in
    let%bind slot1 = Global_slot_since_genesis.gen in
    let%map slot2 = Global_slot_since_genesis.(gen_incl slot1 max_value) in
    (timing, slot1, slot2))
    ~f:(fun (timing, slot1, slot2) ->
      [%test_pred: Balance.t * Balance.t]
        (Tuple.T2.uncurry Balance.( >= ))
        ( min_balance_at_slot timing ~global_slot:slot1
        , min_balance_at_slot timing ~global_slot:slot2 ) )

let final_vesting_slot_is_the_first_when_minimum_balance_is_0 () =
  Quickcheck.test gen_timing ~f:(fun timing_rec ->
      let timing = Account.Timing.of_record timing_rec in
      let vesting_final_slot = Account.timing_final_vesting_slot timing in
      [%test_eq: Balance.t] Balance.zero
        (min_balance_at_slot timing_rec ~global_slot:vesting_final_slot) ;
      let one_slot_prior =
        Global_slot_since_genesis.(
          sub vesting_final_slot Global_slot_span.(of_int 1))
        |> Option.value_exn
      in
      [%test_pred: Balance.t]
        Balance.(( < ) zero)
        (min_balance_at_slot timing_rec ~global_slot:one_slot_prior) )

let every_vesting_period_minimum_balance_decreases_by_vesting_increment () =
  Quickcheck.test
    (let open Quickcheck in
    let open Generator.Let_syntax in
    (* The amount to be vested after the cliff time must be greater than zero
       or else there is no vesting at all. *)
    let%bind timing_rec =
      Account.gen_timing_at_least_one_vesting_period Balance.max_int
    in
    let timing = Account.Timing.of_record timing_rec in
    let vesting_end = Account.timing_final_vesting_slot timing in
    (* Global_slot addition may overflow, so we need to make sure it won't happen. *)
    let max_slot =
      let open Global_slot_since_genesis in
      sub max_value timing_rec.vesting_period
      |> Option.value_map ~default:vesting_end ~f:(min vesting_end)
    in
    let%map global_slot =
      Global_slot_since_genesis.gen_incl timing_rec.cliff_time max_slot
    in
    (timing_rec, global_slot))
    ~f:(fun (timing_rec, global_slot) ->
      let vesting_period_later =
        Global_slot_since_genesis.add global_slot timing_rec.vesting_period
      in
      let min_bal_at_slot = min_balance_at_slot timing_rec ~global_slot in
      let min_bal_later =
        min_balance_at_slot timing_rec ~global_slot:vesting_period_later
      in
      [%test_eq: Balance.t] min_bal_later
        Balance.(
          Option.value ~default:zero
          @@ (min_bal_at_slot - timing_rec.vesting_increment)) )

let incremental_balance_between_slots_before_cliff_is_0 () =
  Quickcheck.test
    (let open Quickcheck.Generator.Let_syntax in
    let%bind timing = gen_timing in
    let max_slot =
      Global_slot_since_genesis.(
        sub timing.cliff_time Global_slot_span.(of_int 1))
      |> Option.value ~default:Global_slot_since_genesis.zero
    in
    let%bind slot1 = Global_slot_since_genesis.(gen_incl zero max_slot) in
    let%map slot2 = Global_slot_since_genesis.gen_incl slot1 max_slot in
    (timing, slot1, slot2))
    ~f:(fun (timing, start_slot, end_slot) ->
      [%test_eq: Balance.t] Balance.zero
        (incr_bal_between timing ~start_slot ~end_slot) )

let incremental_balance_between_slots_after_vesting_finished_is_0 () =
  Quickcheck.test
    (let open Quickcheck.Generator.Let_syntax in
    let%bind timing = gen_timing in
    let vesting_end =
      Account.timing_final_vesting_slot (Account.Timing.of_record timing)
    in
    let%bind slot1 =
      Global_slot_since_genesis.(gen_incl vesting_end max_value)
    in
    let%map slot2 = Global_slot_since_genesis.(gen_incl slot1 max_value) in
    (timing, slot1, slot2))
    ~f:(fun (timing, start_slot, end_slot) ->
      [%test_eq: Balance.t] Balance.zero
        (incr_bal_between timing ~start_slot ~end_slot) )

let incremental_balance_where_end_is_before_start_is_0 () =
  Quickcheck.test
    (let open Quickcheck.Generator.Let_syntax in
    let%bind timing = gen_timing in
    let%bind slot1 = Global_slot_since_genesis.gen in
    let%map slot2 = Global_slot_since_genesis.(gen_incl zero slot1) in
    (timing, slot1, slot2))
    ~f:(fun (timing, start_slot, end_slot) ->
      [%test_eq: Balance.t] Balance.zero
        (incr_bal_between timing ~start_slot ~end_slot) )

let incremental_balance_during_vesting_is_a_multiple_of_vesting_increment () =
  Quickcheck.test
    (let open Quickcheck in
    let open Generator.Let_syntax in
    let%bind timing =
      Account.gen_timing_at_least_one_vesting_period Balance.max_int
    in
    let min_slot =
      Global_slot_since_genesis.(
        add timing.cliff_time Global_slot_span.(of_int 1))
    in
    let max_slot =
      let open Global_slot_since_genesis in
      sub
        Account.(timing_final_vesting_slot @@ Timing.of_record timing)
        Global_slot_span.(of_int 1)
      |> Option.value ~default:zero
    in
    let%bind slot1 = Global_slot_since_genesis.gen_incl min_slot max_slot in
    let%map slot2 = Global_slot_since_genesis.gen_incl slot1 max_slot in
    (timing, slot1, slot2))
    ~f:(fun (timing, start_slot, end_slot) ->
      let open UInt64 in
      [%test_eq: int] 0
        ( to_int
        @@ rem
             (Balance.to_uint64 @@ incr_bal_between timing ~start_slot ~end_slot)
             (Amount.to_uint64 timing.vesting_increment) ) )

let liquid_balance_in_untimed_account_equals_balance () =
  Quickcheck.test
    (let open Quickcheck.Generator.Let_syntax in
    let%bind account = Account.gen in
    let%map global_slot = Global_slot_since_genesis.gen in
    (account, global_slot))
    ~f:(fun (account, global_slot) ->
      [%test_eq: Balance.t] account.balance
        Account.(liquid_balance_at_slot account ~global_slot) )

let liquid_balance_is_balance_minus_minimum_balance_at_given_slot () =
  Quickcheck.test
    (let open Quickcheck.Generator.Let_syntax in
    let%bind account = Account.gen_timed in
    let%map global_slot = Global_slot_since_genesis.gen in
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

let minimum_balance_checked_equal_to_unchecked () =
  let global_slot_span_var gs = Global_slot_span.Checked.constant gs in
  let global_slot_since_genesis_var gs =
    Global_slot_since_genesis.Checked.constant gs
  in
  Quickcheck.test
    (let open Quickcheck.Generator.Let_syntax in
    let%bind timing = gen_timing in
    (* After this slot the value of vesting decrement to the
       minimum balance overflows, which is not currently handled
       properly and causes an error. Remove this constraint when
       the issue #12892 is resolved. *)
    let max_slot =
      let open UInt64.Infix in
      Amount.(to_uint64 max_int)
      / Amount.to_uint64 timing.vesting_increment
      * UInt64.of_uint32 (Global_slot_span.to_uint32 timing.vesting_period)
      |> UInt64.to_uint32
      |> UInt32.add (Global_slot_since_genesis.to_uint32 timing.cliff_time)
      |> Global_slot_since_genesis.of_uint32
    in
    let%map global_slot = Global_slot_since_genesis.(gen_incl zero max_slot) in
    (timing, global_slot))
    ~f:(fun (timing, global_slot) ->
      let min_balance = min_balance_at_slot timing ~global_slot in
      let min_balance_checked =
        Account.Checked.min_balance_at_slot
          ~initial_minimum_balance:
            Balance.(var_of_t timing.initial_minimum_balance)
          ~cliff_amount:Amount.(var_of_t timing.cliff_amount)
          ~cliff_time:(global_slot_since_genesis_var timing.cliff_time)
          ~vesting_increment:Amount.(var_of_t timing.vesting_increment)
          ~vesting_period:(global_slot_span_var timing.vesting_period)
          ~global_slot:(global_slot_since_genesis_var global_slot)
        |> Snarky_backendless.(
             Checked_runner.Simple.map ~f:(As_prover0.read Balance.typ))
        |> Snark_params.Tick.run_and_check
      in
      [%test_eq: Balance.t Or_error.t] (Ok min_balance) min_balance_checked )

let token_symbol_to_bits_of_bits_roundtrip () =
  let open Account.Token_symbol in
  Quickcheck.test ~trials:30 ~seed:(`Deterministic "")
    (Quickcheck.Generator.list_with_length
       (Pickles_types.Nat.to_int Num_bits.n)
       Quickcheck.Generator.bool )
    ~f:(fun x ->
      let v = Pickles_types.Vector.of_list_and_length_exn x Num_bits.n in
      Pickles_types.Vector.iter2
        (to_bits (of_bits v))
        v
        ~f:(fun x y -> assert (Bool.equal x y)) )

let token_symbol_of_bits_to_bits_roundtrip () =
  let open Account.Token_symbol in
  Quickcheck.test ~trials:30 ~seed:(`Deterministic "")
    (let open Quickcheck.Generator.Let_syntax in
    let%bind len = Int.gen_incl 0 max_length in
    String.gen_with_length len
      (Char.gen_uniform_inclusive Char.min_value Char.max_value))
    ~f:(fun x -> assert (String.equal (of_bits (to_bits x)) x))
