open Core_kernel
open Async
module Single_worker = Snark_worker.Single_worker.Prod
module Work = Snark_work_lib
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
      Caml.Format.printf "Successfully generated proof bundle mutation.\n" ;
      exit 0
  | Error (`Failed_request s) ->
      Caml.Format.printf !"Request failed:  %s\n" s ;
      exit 1
  | Error (`Graphql_error s) ->
      Caml.Format.printf "Graphql error: %s\n" s ;
      exit 1

let proof_cache_db = Proof_cache_tag.create_identity_db ()

let perform (s : Single_worker.Worker_state.t) ~fee ~public_key
    (instances : Work.Selector.Single.Spec.t One_or_two.t) =
  One_or_two.Deferred_result.map instances ~f:(fun w ->
      let open Deferred.Or_error.Let_syntax in
      let%map proof, time =
        Single_worker.perform_single s
          ~message:(Mina_base.Sok_message.create ~fee ~prover:public_key)
          w
      in
      ( proof
      , (time, match w with Transition _ -> `Transition | Merge _ -> `Merge) ) )
  |> Deferred.Or_error.map ~f:(fun proofs_and_time ->
         { Snark_work_lib.Work.Result_without_metrics.proofs =
             One_or_two.map proofs_and_time ~f:fst
         ; statements =
             One_or_two.map instances
               ~f:Snark_work_lib.Work.Single.Spec.statement
         ; prover = public_key
         ; fee
         } )

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Run snark worker directly"
    (let%map_open spec_sexp_file =
       flag "--spec-sexp-file"
         ~doc:"Snark work spec in sexp file (preferred over --spec-sexp) "
         (optional string)
     and spec_sexp =
       flag "--spec-sexp" ~doc:"Snark work spec in sexp format"
         (optional string)
     and proof_level =
       flag "--proof-level" ~doc:""
         (optional_with_default Genesis_constants.Proof_level.Full
            (Command.Arg_type.of_alist_exn
               [ ("Full", Genesis_constants.Proof_level.Full)
               ; ("Check", Check)
               ; ("None", No_check)
               ] ) )
     and snark_work_fee =
       flag "--snark-worker-fee" ~aliases:[ "snark-worker-fee" ]
         ~doc:
           (sprintf
              "FEE Amount a worker wants to get compensated for generating a \
               snark proof" )
         (optional Cli_lib.Arg_type.txn_fee)
     and snark_worker_key =
       flag "--snark-worker-public-key"
         ~aliases:[ "snark-worker-public-key" ]
         ~doc:
           (sprintf "PUBLICKEY Run the SNARK worker with this public key. %s"
              Cli_lib.Default.receiver_key_warning )
         (optional Cli_lib.Arg_type.public_key_compressed)
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
         Single_worker.Worker_state.create ~constraint_constants ~proof_level ()
       in

       let%bind sexp =
         match (spec_sexp_file, spec_sexp) with
         | Some sexp_file, _ ->
             let%map content = Reader.file_contents sexp_file in
             Sexp.of_string content
         | None, Some sexp ->
             return (Sexp.of_string sexp)
         | None, None ->
             failwith "No spec provided"
       in
       let spec =
         One_or_two.t_of_sexp
           (Snark_work_lib.Work.Single.Spec.t_of_sexp
              Transaction_witness.Stable.Latest.t_of_sexp Ledger_proof.t_of_sexp )
           sexp
         |> One_or_two.map
              ~f:
                (Work.Selector.Single.Spec.write_all_proofs_to_disk
                   ~proof_cache_db )
       in
       let public_key =
         Option.value
           ~default:(fst Key_gen.Sample_keypairs.genesis_winner)
           snark_worker_key
       in
       let fee =
         Option.value
           ~default:(Currency.Fee.of_nanomina_int_exn 10)
           snark_work_fee
       in
       match%bind perform worker_state ~fee ~public_key spec with
       | Ok result -> (
           Caml.Format.printf
             !"@[<v>Successfully proved. Result: \n\
              \               %{sexp: Ledger_proof.t \
               Snark_work_lib.Work.Result_without_metrics.t}@]@."
             result ;
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
