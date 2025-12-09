open Alcotest
open Async
open Core
open Delegation_verify_lib
open Frontier_base
open Transition_frontier
module State_hash = Mina_base.State_hash

(* Pure Data_source implementation for testing *)
module Pure = struct
  type submission =
    { block_hash : string; request : Uptime_service.Payload.request }

  type t = submission list

  let submitted_at (s : submission) = s.request.data.created_at

  let block_hash (s : submission) = s.block_hash

  let snark_work (s : submission) =
    match s.request.data.snark_work with
    | None ->
        Ok None
    | Some encoded_work -> (
        match Submission.decode_snark_work encoded_work with
        | Ok work ->
            Ok (Some work)
        | Error err ->
            Error err )

  let submitter (s : submission) =
    Signature_lib.Public_key.compress s.request.submitter

  let load_submissions t = Deferred.Or_error.return t

  let load_block (s : submission) t =
    let opt_block =
      List.find_opt
        (fun { block_hash; _ } -> String.equal block_hash s.block_hash)
        t
    in
    Option.fold
      ~none:(Deferred.Or_error.fail @@ Base.Error.of_string "block not found")
      ~some:(fun { request; _ } -> Deferred.Or_error.return request.data.block)
      opt_block

  let output _ (_submission : submission) = function
    | Ok payload ->
        Output.display payload ;
        Deferred.Or_error.return ()
    | Error e ->
        Output.display_error @@ Base.Error.to_string_hum e ;
        Deferred.Or_error.return ()

  let verify_blockchain_snarks, verify_transaction_snarks =
    Delegation_verify_lib.Verifier.verify_functions
      ~constraint_constants:Genesis_constants.Compiled.constraint_constants
      ~proof_level:Full ~signature_kind:Testnet ()

  let verify_blockchain_snarks = verify_blockchain_snarks

  let verify_transaction_snarks = verify_transaction_snarks
end

module Verifier = Delegation_verify_lib.Verifier.Make (Pure)

(* Focused integration test *)

let test_uptime_to_verifier_integration () =
  let open Async.Let_syntax in
  (* Create verifier using same pattern as full_frontier_tests.ml *)
  let verifier = Full_frontier.For_tests.verifier () in

  (* Generate a real breadcrumb using existing test infrastructure *)
  let make_breadcrumb =
    Quickcheck.Generator.generate
      (Full_frontier.For_tests.gen_breadcrumb ~verifier ())
      ~size:1
      ~random:
        (Splittable_random.State.create (Base.Random.State.make_self_init ()))
  in

  let%bind frontier =
    Full_frontier.For_tests.create_frontier ~epoch_ledger_backing_type:Stable_db
      ()
  in

  let root = Full_frontier.root frontier in
  let%bind real_breadcrumb = make_breadcrumb root in

  (* Create uptime service payload using the real breadcrumb *)
  let peer_id = "test_peer" in
  let submitter_keypair = Signature_lib.Keypair.create () in
  let graphql_control_port = Some 8080 in
  let built_with_commit_sha = Some "test_commit" in

  let real_payload =
    Uptime_service.generate_block_submission_data ~peer_id ~submitter_keypair
      ~graphql_control_port ~built_with_commit_sha real_breadcrumb
  in

  (* Create test submission using real payload *)
  let test_submission =
    { Pure.block_hash =
        Breadcrumb.state_hash real_breadcrumb |> State_hash.to_base58_check
    ; request = real_payload
    }
  in

  (* Run the verification on single submission *)
  let%bind verification_result =
    Verifier.verify ~validate:true test_submission
  in

  (* Clean up *)
  Full_frontier.For_tests.clean_up_persistent_root ~frontier ;

  (* Assert verification succeeded *)
  return
  @@
  match verification_result with
  | Ok _ ->
      ()
  | Error err ->
      failwith ("Verification failed: " ^ Base.Error.to_string_hum err)

(* Test suite configuration *)
let () =
  run "delegation_verify tests"
    [ ( "integration"
      , [ test_case "uptime to verifier integration" `Quick (fun () ->
              Async.Thread_safe.block_on_async_exn
                test_uptime_to_verifier_integration )
        ] )
    ]
