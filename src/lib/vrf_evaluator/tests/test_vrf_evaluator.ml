(** Testing
    -------
    Component: Vrf_evaluator
    Subject: Testing the VRF evaluator's slot search
    Invocation: dune exec \
      src/lib/vrf_evaluator/tests/test_vrf_evaluator.exe
*)

open Core

module Search_deadline_tests = struct
  let time ms = Block_time.of_int64 (Int64.of_int ms)

  let slot_start = time 100_000

  let slot_duration = Block_time.Span.of_ms 10_000L

  let check name ~current_time ~expected =
    Alcotest.(check (option int64))
      name
      (Option.map ~f:Block_time.to_int64 expected)
      (Option.map ~f:Block_time.to_int64
         (Vrf_evaluator.Worker_state.search_deadline
            ~current_time:(time current_time) ~slot_start ~slot_duration ) )

  let test_far_enough_ahead () =
    check "long before the lead deadline" ~current_time:0
      ~expected:(Some (time 80_000)) ;
    check "just before the lead deadline" ~current_time:79_999
      ~expected:(Some (time 80_000))

  let test_too_close () =
    check "at the lead deadline" ~current_time:80_000
      ~expected:(Some (time 105_000)) ;
    check "at the slot start" ~current_time:100_000
      ~expected:(Some (time 105_000)) ;
    check "just before the midpoint" ~current_time:104_999
      ~expected:(Some (time 105_000))

  let test_past_midpoint () =
    check "at the midpoint" ~current_time:105_000 ~expected:None ;
    check "after the slot" ~current_time:200_000 ~expected:None
end

module Delegators_by_stake_tests = struct
  open Mina_base

  let test_order () =
    let producer_with_delegators = Signature_lib.Keypair.create () in
    let other_producer_with_delegators = Signature_lib.Keypair.create () in
    let producer_without_delegators = Signature_lib.Keypair.create () in
    let keypairs =
      List.map
        [ producer_with_delegators
        ; other_producer_with_delegators
        ; producer_without_delegators
        ] ~f:(fun keypair ->
          (keypair, Signature_lib.Public_key.compress keypair.public_key) )
    in
    let delegator balance =
      Account.create
        (Account_id.create
           (Signature_lib.Public_key.compress
              (Signature_lib.Keypair.create ()).public_key )
           Token_id.default )
        (Currency.Balance.of_mina_int_exn balance)
    in
    let delegators_of (keypair : Signature_lib.Keypair.t) delegators =
      ( Signature_lib.Public_key.compress keypair.public_key
      , Account.Index.Table.of_alist_exn
          (List.map delegators ~f:(fun (index, balance) ->
               (index, delegator balance) ) ) )
    in
    let epoch_data : Consensus.Data.Epoch_data_for_vrf.t =
      { epoch_ledger =
          { hash = Frozen_ledger_hash.of_ledger_hash Ledger_hash.empty_hash
          ; total_currency = Currency.Amount.of_mina_int_exn 75
          }
      ; epoch_seed = Epoch_seed.of_hash Snark_params.Tick.Field.zero
      ; epoch = Mina_numbers.Length.zero
      ; global_slot = Mina_numbers.Global_slot_since_hard_fork.zero
      ; global_slot_since_genesis = Mina_numbers.Global_slot_since_genesis.zero
      ; delegatee_table =
          Signature_lib.Public_key.Compressed.Table.of_alist_exn
            [ delegators_of producer_with_delegators
                [ (0, 5); (3, 20); (4, 10) ]
            ; delegators_of other_producer_with_delegators [ (1, 10); (2, 30) ]
            ]
      }
    in
    let order =
      Vrf_evaluator.Worker_state.delegators_by_stake ~epoch_data ~keypairs
      |> List.map ~f:(fun ((_, producer), delegator, _) ->
             ( Signature_lib.Public_key.Compressed.to_base58_check producer
             , delegator ) )
    in
    let producer (keypair : Signature_lib.Keypair.t) =
      Signature_lib.Public_key.(
        Compressed.to_base58_check (compress keypair.public_key))
    in
    Alcotest.(check (list (pair string int)))
      "largest stake first, ties broken by delegator index"
      [ (producer other_producer_with_delegators, 2)
      ; (producer producer_with_delegators, 3)
      ; (producer other_producer_with_delegators, 1)
      ; (producer producer_with_delegators, 4)
      ; (producer producer_with_delegators, 0)
      ]
      order
end

let () =
  let open Alcotest in
  run "VRF evaluator tests"
    [ ( "search_deadline"
      , [ test_case "far enough ahead stops at the lead deadline" `Quick
            Search_deadline_tests.test_far_enough_ahead
        ; test_case "too close stops at the midpoint" `Quick
            Search_deadline_tests.test_too_close
        ; test_case "past the midpoint is skipped" `Quick
            Search_deadline_tests.test_past_midpoint
        ] )
    ; ( "delegators_by_stake"
      , [ test_case "orders the delegators of every key by stake" `Quick
            Delegators_by_stake_tests.test_order
        ] )
    ]
