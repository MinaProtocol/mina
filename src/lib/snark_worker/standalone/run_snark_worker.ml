open Core_kernel
open Async
module Prod = Snark_worker.Inputs
module Graphql_client = Graphql_lib.Client
module Encoders = Mina_graphql.Types.Input
module Scalars = Graphql_lib.Scalars

module Send_proof_mutation =
[%graphql
({|
  mutation ($input: ProofBundleInput!) @encoders(module: "Encoders"){
    sendProofBundle(input: $input)
    }
  |}
[@encoders Encoders] )]

let submit_graphql input graphql_endpoint =
  let obj = Send_proof_mutation.(make @@ makeVariables ~input ()) in
  match%bind Graphql_client.query obj graphql_endpoint with
  | Ok _s ->
      Format.printf "Successfully generated proof bundle mutation.\n" ;
      exit 0
  | Error (`Failed_request s) ->
      Format.printf "Request failed:  %s\n" s ;
      exit 1
  | Error (`Graphql_error s) ->
      Format.printf "Graphql error: %s\n" s ;
      exit 1

let perform (s : Prod.Worker_state.t) ~fee ~public_key
    (spec :
      ( Transaction_witness.Stable.Latest.t
      , Ledger_proof.t )
      Snark_work_lib.Work.Single.Spec.t
      One_or_two.t ) =
  One_or_two.Deferred_result.map spec ~f:(fun w ->
      let open Deferred.Or_error.Let_syntax in
      let%map proof, time =
        Prod.perform_single s
          ~message:(Mina_base.Sok_message.create ~fee ~prover:public_key)
          w
      in
      ( proof
      , (time, match w with Transition _ -> `Transition | Merge _ -> `Merge) ) )
  |> Deferred.Or_error.map ~f:(fun proofs_and_time ->
         { Snark_work_lib.Work.Result_without_metrics.proofs =
             One_or_two.map proofs_and_time ~f:fst
         ; statements =
             One_or_two.map spec ~f:Snark_work_lib.Work.Single.Spec.statement
         ; prover = public_key
         ; fee
         } )

let command =
  let open struct
    module Work = Snark_work_lib
  end in
  let open Command.Let_syntax in
  Command.async ~summary:"Run snark worker directly"
    (let%map_open dumped_spec =
       flag "--dumped-spec" ~doc:"Spec dumped on disk" (required string)
     and proof_output =
       flag "--proof-output" ~doc:"File to save proof output" (required string)
     and proof_level =
       flag "--proof-level" ~doc:""
         (optional_with_default Genesis_constants.Proof_level.Full
            (Command.Arg_type.of_alist_exn
               [ ("Full", Genesis_constants.Proof_level.Full)
               ; ("Check", Check)
               ; ("None", No_check)
               ] ) )
     and proof_submission_graphql_endpoint =
       flag "--graphql-uri" ~doc:"Graphql endpoint to submit proofs"
         (optional Cli_lib.Arg_type.uri)
     in
     fun () ->
       let open Async in
       let constraint_constants =
         Genesis_constants.Compiled.constraint_constants
       in
       let%bind worker_state =
         Prod.Worker_state.create ~constraint_constants ~proof_level ()
       in
       let Work.Spec.Dumped.{ fee; prover; spec } =
         Yojson.Safe.from_file dumped_spec
         |> Work.Spec.Dumped.of_yojson |> Result.ok_or_failwith
       in
       match%bind perform worker_state ~fee ~public_key:prover spec with
       | Ok result -> (
           Work.Work.Result_without_metrics.to_yojson Ledger_proof.to_yojson
             result
           |> Yojson.Safe.to_file proof_output ;
           match proof_submission_graphql_endpoint with
           | Some endpoint ->
               submit_graphql result endpoint
           | _ ->
               Deferred.unit )
       | Error err ->
           Caml.Format.printf
             !"Proving failed with error: %s@."
             (Error.to_string_hum err) ;
           exit 1 )

let () = Command.run command
