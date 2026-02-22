(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^slot reduction vesting update$'
    Subject:    Test slot reduction vesting parameter update equations.
 *)

open Core_kernel
open Currency
open Mina_base
open Mina_numbers
open Unsigned
open Account.Timing.As_record

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

type vesting_spec =
  { vesting_period_min : Global_slot_span.t
  ; vesting_period_max : Global_slot_span.t
  ; vesting_end_min : UInt32.t
  ; vesting_end_max : UInt32.t
  ; initial_minimum_balance_min : Balance.t
  ; initial_minimum_balance_max : Balance.t
  }

let gen_vesting_timing_with ~(spec : vesting_spec) =
  let open Quickcheck.Generator.Let_syntax in
  let%bind vesting_period =
    Global_slot_span.gen_incl spec.vesting_period_min spec.vesting_period_max
  in
  let%bind vesting_end =
    Global_slot_since_genesis.(
      gen_incl (of_uint32 spec.vesting_end_min) (of_uint32 spec.vesting_end_max))
  in
  let%bind cliff_time =
    Global_slot_since_genesis.(gen_incl (of_int 1) vesting_end)
  in
  let%bind initial_minimum_balance =
    Balance.(
      gen_incl spec.initial_minimum_balance_min spec.initial_minimum_balance_max)
  in
  Account.gen_vesting_details ~cliff_time ~vesting_end ~vesting_period
    initial_minimum_balance

(* Generate an account timing with a "reasonable" vesting schedule, i.e., one
   that won't take ages to finish *)
let gen_small_timing =
  (* This is some arbitrary slot that will result in a generated vesting timing
     that lies comfortably in the ranges that the slot reduction MIP's
     guarantees apply to. At 90s slot time, this slot will occur 375 years after
     slot 0 *)
  let vesting_end_max = UInt32.(div max_int (of_int 32)) in
  let spec : vesting_spec =
    { vesting_period_min = Global_slot_span.one
    ; vesting_period_max = Global_slot_span.of_int 100
    ; vesting_end_min = UInt32.one
    ; vesting_end_max
    ; initial_minimum_balance_min = Balance.one
    ; initial_minimum_balance_max = Balance.max_int
    }
  in
  gen_vesting_timing_with ~spec

(* Generate a timing with a very long period. *)
let gen_large_period_timing =
  (* The vesting_end_min and vesting_period_min are arbitrary large slots that
     will usually result in a generated timing that lies outside of guarantees
     provided by the slot reduction MIP. *)
  let vesting_end_max = UInt32.max_int in
  let vesting_end_min = UInt32.(div vesting_end_max (of_int 32)) in
  let spec : vesting_spec =
    { vesting_period_min =
        (Global_slot_span.of_uint32 @@ UInt32.(div max_int (of_int 3)))
    ; vesting_period_max = Global_slot_span.max_value
    ; vesting_end_min
    ; vesting_end_max
    ; initial_minimum_balance_min = Balance.one
    ; initial_minimum_balance_max = Balance.max_int
    }
  in
  gen_vesting_timing_with ~spec

let gen_hardfork_timing =
  Quickcheck.Generator.weighted_union
    [ (1.0, gen_small_timing); (1.0, gen_large_period_timing) ]

(** Return the slot at which the account completes vesting. This is the earliest
    slot at which the current minimum balance for the account is zero. The
    difference in balance between this returned slot and the previous slot will
    be the [cliff_amount] if the account vests completely at its [cliff_time],
    and otherwise will be the [vesting_increment] *)
let final_vesting_slot (t : Account.Timing.as_record) =
  (* timing_final_vesting_slot assumes vesting_increment is non-zero, but we
     want to be able to handle such accounts here. *)
  if Amount.(equal t.vesting_increment zero) then t.cliff_time
  else Account.timing_final_vesting_slot @@ Account.Timing.of_record t

(** Generate a slot at which the account in question is vesting. *)
let gen_slot_during_vesting ~(timing : Account.Timing.as_record) =
  let vesting_end = final_vesting_slot timing in
  let half_period =
    timing.vesting_period |> Global_slot_span.to_uint32
    |> UInt32.(Fn.flip div (of_int 2))
    |> Global_slot_span.of_uint32
  in
  let at_most_cliff =
    let half_period_before_cliff =
      Global_slot_since_genesis.(
        sub timing.cliff_time half_period |> Option.value ~default:zero)
    in
    (half_period_before_cliff, timing.cliff_time)
  in
  let right_before_cliff =
    let slot_right_before_cliff =
      Global_slot_since_genesis.(
        sub timing.cliff_time Global_slot_span.one |> Option.value ~default:zero)
    in
    (slot_right_before_cliff, slot_right_before_cliff)
  in
  let at_cliff = (timing.cliff_time, timing.cliff_time) in
  let right_after_cliff =
    Global_slot_since_genesis.(
      (* If cliff_time is the final slot, it doesn't make sense to try to
         generate a value in this range *)
      if equal timing.cliff_time max_value then (max_value, zero)
      else
        let slot_right_after_cliff =
          add timing.cliff_time Global_slot_span.one
        in
        (slot_right_after_cliff, slot_right_after_cliff))
  in
  let at_least_cliff =
    let just_before_end =
      Global_slot_since_genesis.(
        sub vesting_end Global_slot_span.one |> Option.value ~default:zero)
    in
    (timing.cliff_time, just_before_end)
  in
  (* We want to pick slots from intervals that are non-empty and are contained
     in the period before vesting end *)
  let intervals =
    [ (1.0, at_most_cliff)
    ; (1.0, right_before_cliff)
    ; (1.0, at_cliff)
    ; (1.0, right_after_cliff)
    ; (1.0, at_least_cliff)
    ]
    |> List.filter_map ~f:(fun (weight, (low, high)) ->
           if
             Global_slot_since_genesis.(compare low high) <= 0
             && Global_slot_since_genesis.(compare high vesting_end) < 0
           then Some (weight, Global_slot_since_genesis.(gen_incl low high))
           else None )
  in
  Quickcheck.Generator.weighted_union intervals

(** Generate a slot at which the account has finished vesting. Note that the
    [final_vesting_slot] is such a slot! *)
let gen_slot_after_vesting ~(timing : Account.Timing.as_record) =
  let vesting_end = final_vesting_slot timing in
  Global_slot_since_genesis.(gen_incl vesting_end max_value)

(** Generate an account timing that is actively vesting at the hardfork slot *)
let gen_actively_vesting_at_hardfork =
  let open Quickcheck.Generator.Let_syntax in
  let%bind timing = gen_hardfork_timing in
  let%map hardfork_slot = gen_slot_during_vesting ~timing in
  (timing, hardfork_slot)

(** Generate an account timing that is actively vesting at the hardfork slot, or
    cliffs at the hardfork slot. Note that an account that vests completely at
    its cliff_time does not count as actively vesting at cliff_time! *)
let gen_vesting_or_cliff_at_hardfork =
  let open Quickcheck.Generator.Let_syntax in
  let%bind timing = gen_hardfork_timing in
  let%map hardfork_slot =
    Quickcheck.Generator.weighted_union
      [ (1.0, gen_slot_during_vesting ~timing)
      ; (1.0, Quickcheck.Generator.return timing.cliff_time)
      ]
  in
  (timing, hardfork_slot)

let gen_not_vesting_at_hardfork =
  let open Quickcheck.Generator.Let_syntax in
  let%bind timing = gen_hardfork_timing in
  let%map hardfork_slot = gen_slot_after_vesting ~timing in
  (timing, hardfork_slot)

(** Generate any account timing with hardfork slot that can occur before or
    after vesting ends *)
let gen_any_at_hardfork =
  let open Quickcheck.Generator.Let_syntax in
  let%bind timing = gen_hardfork_timing in
  let%map hardfork_slot =
    Quickcheck.Generator.weighted_union
      [ (1.0, gen_slot_during_vesting ~timing)
      ; (1.0, gen_slot_after_vesting ~timing)
      ]
  in
  (timing, hardfork_slot)

(** True if a regular [Account.Timing.as_record] counts as actively vesting
    according to [Account_timing.Slot_reduction_update.is_actively_vesting] *)
let is_actively_vesting ~global_slot (t : Account.Timing.as_record) =
  Account_timing.Slot_reduction_update.(
    t |> of_record |> is_actively_vesting ~global_slot)

(** Test that the generator for not-actively-vesting accounts produces accounts
    that aren't considered actively vesting *)
let not_vesting_after_vesting () =
  Quickcheck.test gen_not_vesting_at_hardfork ~f:(fun (timing, hardfork_slot) ->
      [%test_pred: Global_slot_since_genesis.t]
        (fun slot -> not @@ is_actively_vesting ~global_slot:slot timing)
        hardfork_slot )

(** Test that the generator for actively vesting accounts produces accounts that
    are in fact considered actively vesting *)
let vesting_before_vesting_end () =
  Quickcheck.test gen_actively_vesting_at_hardfork
    ~sexp_of:(fun (timing, global_slot) ->
      [%sexp_of:
        Account_timing.Slot_reduction_update.t * Global_slot_since_genesis.t]
        (Account_timing.Slot_reduction_update.of_record timing, global_slot) )
    ~f:(fun (timing, global_slot) ->
      assert (is_actively_vesting ~global_slot timing) )

let record_conversion_roundtrip () =
  Quickcheck.test gen_any_at_hardfork ~f:(fun (timing, _global_slot) ->
      let timing = Account_timing.Slot_reduction_update.of_record timing in
      assert (
        Account_timing.Slot_reduction_update.(
          equal timing (of_record @@ to_record timing)) ) )

let half_max_global_slot =
  Global_slot_since_genesis.(
    max_value |> to_uint32 |> UInt32.(Fn.flip div (of_int 2)) |> of_uint32)

let slot_at_most_half_max global_slot =
  Global_slot_since_genesis.compare global_slot half_max_global_slot <= 0

let funds_unlocked_at_slot ~global_slot (t : Account.Timing.as_record) =
  let prev_slot =
    Global_slot_since_genesis.sub global_slot Global_slot_span.one
    |> Option.value_exn
  in
  incr_bal_between ~start_slot:prev_slot ~end_slot:global_slot t

(** Test that our local [final_vesting_slot] correctly predicts the final
    vesting slot *)
let unadjusted_vesting_ends_as_expected () =
  Quickcheck.test gen_hardfork_timing ~f:(fun timing ->
      let vesting_end = final_vesting_slot timing in
      (* Test that we unlocked funds at vesting_end, and that the minimum
         balance is zero at vesting_end *)
      [%test_pred: Balance.t * Balance.t]
        (fun (unlocked, new_balance) ->
          (not Balance.(equal unlocked zero))
          && Balance.(equal new_balance zero) )
        ( funds_unlocked_at_slot ~global_slot:vesting_end timing
        , min_balance_at_slot ~global_slot:vesting_end timing ) )

(** If a pre-hardfork account is scheduled to complete vesting at slot
    [vesting_end = hardfork_slot + k] and [vesting_end] is not too large (at
    most half the maximum slot), then the post-adjustment account must complete
    vesting at slot [hardfork_slot + 2*k] in order to finish vesting at the same
    system time as it would have without the hardfork. *)
let fast_vesting_ends_as_expected () =
  Quickcheck.test
    ( gen_vesting_or_cliff_at_hardfork
    |> Quickcheck.Generator.filter_map ~f:(fun (timing, hardfork_slot) ->
           let vesting_end = final_vesting_slot timing in
           if slot_at_most_half_max vesting_end then
             Some (timing, hardfork_slot, vesting_end)
           else None ) )
    ~f:(fun (timing, hardfork_slot, vesting_end) ->
      let pre_hardfork_vesting_span =
        Global_slot_since_genesis.(diff vesting_end hardfork_slot)
        |> Option.value_exn |> Global_slot_span.to_uint32
      in
      let post_hardfork_vesting_span =
        UInt32.(mul pre_hardfork_vesting_span (of_int 2))
        |> Global_slot_span.of_uint32
      in
      let post_hardfork_vesting_end =
        Global_slot_since_genesis.add hardfork_slot post_hardfork_vesting_span
      in
      let adjusted_timing =
        Account_timing.slot_reduction_update ~hardfork_slot timing
      in
      (* Make sure that: (1) the funds unlocked at the adjusted vesting end slot
         are the same; (2) the minimum balance at the adjusted end slot are the
         same; (3) the minimum balance at the adjustend end slot is zero *)
      [%test_eq: Balance.t * Balance.t * Balance.t]
        ( funds_unlocked_at_slot ~global_slot:vesting_end timing
        , min_balance_at_slot ~global_slot:vesting_end timing
        , Balance.zero )
        ( funds_unlocked_at_slot ~global_slot:post_hardfork_vesting_end
            adjusted_timing
        , min_balance_at_slot ~global_slot:post_hardfork_vesting_end timing
        , min_balance_at_slot ~global_slot:post_hardfork_vesting_end timing ) )

(** Test that the minimum account balance is the same at the [hardfork_slot]
    before and after the upate procedure *)
let minimum_balance_unchanged_at_hardfork () =
  Quickcheck.test gen_any_at_hardfork ~f:(fun (timing, hardfork_slot) ->
      [%test_eq: Balance.t]
        (min_balance_at_slot ~global_slot:hardfork_slot timing)
        (min_balance_at_slot ~global_slot:hardfork_slot
           (Account_timing.slot_reduction_update ~hardfork_slot timing) ) )

(** The hardfork slot reduction will double the speed at which slots occur,
    starting at the hardfork slot itself. For that reason, slots of the form
    [hardfork_slot + 2*k] (for k >= 0) will occur at the same system time as the
    pre-hardfork slot [hardfork_slot + k] (as long as k is not too large). Since
    we want to preserve the vesting schedule of accounts according to system
    time, we must test that post-hardfork-adjustment accounts unlock the same
    amount of funds at these post-hardfork slots as the pre-adjustment accounts
    unlock at the corresponding pre-hardfork slot.

    Note that we actually only test k > 0 here. Why? Because the vesting
    parameter update doesn't preserve the *historical* minimum balance totals!
    The parameter update will set the new cliff_time to the hardfork_slot for
    all partially-vested accounts, so according to the updated vesting
    parameters we might vest a little bit at exactly the hardfork_slot even if
    we wouldn't have done so before. Thankfully, we don't need to test k = 0
    here anyway, because the guarantee in the MIP is that the minimum balance is
    unchanged at the hardfork slot, and the vesting schedule is preserved
    *starting at* the hardfork slot. The test that's relevant for the
    hardfork_slot itself is thus [minimum_balance_unchanged_at_hardfork]. *)
let no_even_vesting_discrepancies () =
  Quickcheck.test
    (let open Quickcheck.Generator.Let_syntax in
    (* Need to make sure that the hardfork doesn't occur in the last half of the
       global slots, otherwise no test cases will exist! *)
    let%bind timing, hardfork_slot, vesting_end =
      gen_vesting_or_cliff_at_hardfork
      |> Quickcheck.Generator.filter_map ~f:(fun (timing, hardfork_slot) ->
             let vesting_end = final_vesting_slot timing in
             if slot_at_most_half_max vesting_end then
               Some (timing, hardfork_slot, vesting_end)
             else None )
    in
    (* Our test slot can't be exactly hardfork_slot, for the reasons described
       in the doc comment. *)
    let min_pre_hardfork_test_slot =
      Global_slot_since_genesis.succ hardfork_slot
    in
    (* Our test slot on the no-hardfork timeline also can't be more than half
       the max slot, as these slots cease to exist in the with-hardfork
       timeline. *)
    let max_pre_hardfork_test_slot =
      Global_slot_since_genesis.(
        min half_max_global_slot
          (if equal vesting_end max_value then max_value else succ vesting_end))
    in
    let%map pre_hardfork_test_slot =
      Global_slot_since_genesis.(
        gen_incl min_pre_hardfork_test_slot max_pre_hardfork_test_slot)
    in
    (* The with-hardfork timeline test slot is twice the distance from the
       hardfork_slot compared to the without-hardfork timeline *)
    let post_hardfork_test_slot_span =
      Global_slot_since_genesis.(diff pre_hardfork_test_slot hardfork_slot)
      |> Option.value_exn |> Global_slot_span.to_uint32
      |> UInt32.(mul (of_int 2))
      |> Global_slot_span.of_uint32
    in
    let post_hardfork_test_slot =
      Global_slot_since_genesis.(add hardfork_slot post_hardfork_test_slot_span)
    in
    (timing, hardfork_slot, pre_hardfork_test_slot, post_hardfork_test_slot))
    ~f:(fun ( timing
            , hardfork_slot
            , pre_hardfork_test_slot
            , post_hardfork_test_slot ) ->
      [%test_eq: Balance.t]
        (funds_unlocked_at_slot ~global_slot:pre_hardfork_test_slot timing)
        (funds_unlocked_at_slot ~global_slot:post_hardfork_test_slot
           (Account_timing.slot_reduction_update ~hardfork_slot timing) ) )

(** The hardfork slot reduction will double the speed at which slots occur,
    starting at the hardfork slot itself. For that reason, slots of the form
    [hardfork_slot + 2*k + 1] (for k >= 0) will occur at a system time halfway
    between two pre-hardfork slots. Since we want to preserve the vesting
    schedule of accounts according to system time, we must test that
    post-hardfork-adjustment accounts never unlock funds at these odd span
    slots. *)
let no_odd_vesting_discrepancies () =
  Quickcheck.test
    (let open Quickcheck.Generator.Let_syntax in
    let%bind timing, hardfork_slot, vesting_end =
      gen_vesting_or_cliff_at_hardfork
      |> Quickcheck.Generator.filter_map ~f:(fun (timing, hardfork_slot) ->
             let vesting_end = final_vesting_slot timing in
             (* Our guarantees only hold for accounts that do not take a long
                time to vest - the property that adjusted accounts only vest at
                even spans does actually fail for certain very long
                schedules. *)
             if not @@ slot_at_most_half_max vesting_end then None
             else if
               (* Also need to make sure that this account is actively vesting
                  for at least one odd-span slot, otherwise no test cases
                  exist *)
               Global_slot_span.(
                 compare
                   ( Global_slot_since_genesis.diff vesting_end hardfork_slot
                   |> Option.value_exn )
                   one)
               >= 0
             then Some (timing, hardfork_slot, vesting_end)
             else None )
    in
    let total_vesting_slots =
      Global_slot_since_genesis.(diff vesting_end hardfork_slot)
      |> Option.value_exn |> Global_slot_span.to_uint32
    in
    let max_post_hardfork_span =
      UInt32.(
        if compare total_vesting_slots (div max_int (of_int 2)) > 0 then max_int
        else mul total_vesting_slots (of_int 2))
      |> Global_slot_span.of_uint32
    in
    let%map post_hardfork_span =
      Global_slot_span.(gen_incl one max_post_hardfork_span)
      |> Quickcheck.Generator.filter ~f:(fun span ->
             let span_uint32 = Global_slot_span.to_uint32 span in
             UInt32.(equal Infix.(span_uint32 mod of_int 2) one) )
    in
    let test_slot =
      Global_slot_since_genesis.(add hardfork_slot post_hardfork_span)
    in
    ( timing
    , Account_timing.slot_reduction_update ~hardfork_slot timing
    , test_slot
    , hardfork_slot ))
    ~sexp_of:(fun (timing, adjusted_timing, test_slot, hardfork_slot) ->
      [%sexp_of:
        Account_timing.Slot_reduction_update.t
        * Account_timing.Slot_reduction_update.t
        * Global_slot_since_genesis.t
        * Global_slot_since_genesis.t]
        Account_timing.Slot_reduction_update.
          (of_record timing, of_record adjusted_timing, test_slot, hardfork_slot)
      )
    ~f:(fun (_timing, adjusted_timing, test_slot, _hardfork_slot) ->
      [%test_eq: Balance.t] Balance.zero
        (funds_unlocked_at_slot ~global_slot:test_slot adjusted_timing) )
