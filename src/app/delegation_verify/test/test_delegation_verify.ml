open Alcotest
open Async
open Core
open Delegation_verify_lib

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
  (* Test: create uptime payload -> run through delegation verifier *)
  let keypair = Signature_lib.Keypair.create () in

  (* Create uptime payload *)
  let payload_request =
    Uptime_service.Payload.
      { version = 1
      ; data =
          { block = "dGVzdF9ibG9ja19kYXRh"
          ; (* "test_block_data" base64 *)
            created_at = "2023-12-09T10:00:00Z"
          ; peer_id = "test_peer"
          ; snark_work = None
          ; graphql_control_port = Some 3085
          ; built_with_commit_sha = Some "abc123"
          }
      ; signature = (Snark_params.Tick.Field.zero, Snark_params.Tock.Field.zero)
      ; submitter = keypair.public_key
      }
  in

  (* Run through verifier using Pure data source *)
  let submission : Pure.submission =
    { block_hash = "test_hash"; request = payload_request }
  in
  let%bind loaded = Pure.load_submissions [ submission ] in

  match loaded with
  | Ok [ s ] ->
      Alcotest.(check string)
        "uptime->verifier integration" "2023-12-09T10:00:00Z"
        (Pure.submitted_at s) ;
      Deferred.return ()
  | _ ->
      failwith "Integration test failed"

(* Test suite configuration *)
let () =
  run "delegation_verify tests"
    [ ( "integration"
      , [ test_case "uptime to verifier integration" `Quick (fun () ->
              Async.Thread_safe.block_on_async_exn
                test_uptime_to_verifier_integration )
        ] )
    ]
