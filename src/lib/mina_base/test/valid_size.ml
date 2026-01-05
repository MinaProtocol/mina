open Core_kernel
open Mina_base.Zkapp_command
open Mina_base

let or_error_testable =
  let pp ppf = function
    | Ok () ->
        Format.fprintf ppf "Ok"
    | Error e ->
        Format.fprintf ppf "Error(%s)" (Error.to_string_hum e)
  in
  Alcotest.testable pp (Or_error.equal (fun () () -> true))

let tree_gen :
    ( Account_update.t
    , Digest.Account_update.t
    , Digest.Forest.t )
    Call_forest.Tree.t
    Quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  let%map account_gen =
    ( Account_update.gen_with_events_and_actions
      : Account_update.Stable.Latest.t Quickcheck.Generator.t )
  in
  let account_update =
    Account_update.write_all_proofs_to_disk
      ~proof_cache_db:(Proof_cache_tag.For_tests.create_db ())
      account_gen
  in
  { Call_forest.Tree.account_update
  ; account_update_digest =
      Digest.Account_update.create ~signature_kind:Mina_signature_kind.Testnet
        account_update
  ; calls = []
  }

let zkapp_type_gen =
  let open Quickcheck.Let_syntax in
  let%bind length = Int.gen_incl 2 1000 in
  let gen_call_forest =
    List.gen_with_length length
    @@ With_stack_hash.quickcheck_generator tree_gen
         Digest.Forest.(Quickcheck.Generator.return empty)
  in
  let%bind fee_payer = Account_update.Fee_payer.gen in
  let%bind account_updates = gen_call_forest in
  let%map memo = Signed_command_memo.gen in
  (({ fee_payer; account_updates; memo } : t), length)

let genesis_constant_error max_zkapp_segment events actions :
    Genesis_constants.t =
  let (module G) = Genesis_constants.profiled () in
  { G.genesis_constants with
    max_zkapp_segment_per_transaction = max_zkapp_segment
  ; max_event_elements = events
  ; max_action_elements = actions
  }

(* Note that in the following tests the generated zkapp_type will have an account_updates (i.e. a call_forest)
   that is a list of variable length (say Length), but each element in that list will always have two events and two actions.
   This means that the number of total actions and total events for the zkapp_type will be 2 * Length for each.
   Thus, in order to generate an error, we just need the genesis file to be defined such that max_event_elements < 2 * Length and similarly for max_action_elements.*)

let valid_size_errors_expensive () =
  Quickcheck.test ~trials:50 zkapp_type_gen ~f:(fun (x, y) ->
      let actual =
        valid_size ~genesis_constants:(genesis_constant_error 1 (2 * y) (2 * y))
        @@ read_all_proofs_from_disk x
      in
      Alcotest.(check or_error_testable)
        "zkapp transaction too expensive"
        (Or_error.error_string "zkapp transaction too expensive")
        actual )

let valid_size_errors_events () =
  Quickcheck.test ~trials:50 zkapp_type_gen ~f:(fun (x, y) ->
      let expected =
        Or_error.errorf "too many event elements (%d, max allowed is %d)"
          (2 * y) y
      in
      let actual =
        valid_size ~genesis_constants:(genesis_constant_error 100000 y (2 * y))
        @@ read_all_proofs_from_disk x
      in
      Alcotest.(check or_error_testable)
        "too many event elements" expected actual )

let valid_size_errors_actions () =
  Quickcheck.test ~trials:50 zkapp_type_gen ~f:(fun (x, y) ->
      let expected =
        Or_error.errorf
          "too many sequence event elements (%d, max allowed is %d)" (2 * y) y
      in
      let actual =
        valid_size ~genesis_constants:(genesis_constant_error 100000 (2 * y) y)
        @@ read_all_proofs_from_disk x
      in
      Alcotest.(check or_error_testable)
        "too many sequence event elements" expected actual )

let returns_ok () =
  Quickcheck.test ~trials:50 zkapp_type_gen ~f:(fun (x, y) ->
      let actual =
        valid_size
          ~genesis_constants:(genesis_constant_error 100000 (2 * y) (2 * y))
        @@ read_all_proofs_from_disk x
      in
      Alcotest.(check or_error_testable) "returns ok" (Ok ()) actual )

let tests =
  ( "valid size"
  , [ Alcotest.test_case "valid_size_errors_expensive" `Quick
        valid_size_errors_expensive
    ; Alcotest.test_case "valid_size_errors_events" `Quick
        valid_size_errors_events
    ; Alcotest.test_case "valid_size_errors_actions" `Quick
        valid_size_errors_actions
    ; Alcotest.test_case "returns ok" `Quick returns_ok
    ] )
