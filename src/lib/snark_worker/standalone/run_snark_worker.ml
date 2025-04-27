open Core_kernel
open Async
module Single_worker = Snark_worker.Impl.Prod
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

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Run snark worker directly"
    (let%map_open spec_json =
       flag "--spec-json"
         ~doc:
           "Snark work spec in json format (preferred over all other formats \
            if several are passed)"
         (optional string)
     and spec_json_file =
       flag "--spec-json-file"
         ~doc:
           "Snark work spec in json file (preferred over sexp format if both \
            are passed)"
         (optional string)
     and spec_sexp =
       flag "--spec-sexp"
         ~doc:
           "Snark work spec in sexp format (json formats are preferred over \
            sexp if both are passed)"
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
       let%bind spec =
         let spec_of_json json =
           match
             Yojson.Safe.from_string json
             |> One_or_two.of_yojson
                  Work.Selector.Single.Spec.Stable.Latest.of_yojson
           with
           | Ok spec ->
               spec
           | Error e ->
               failwith (sprintf "Failed to read json spec. Error: %s" e)
         in
         match spec_json with
         | Some json ->
             return @@ spec_of_json json
         | None -> (
             match spec_json_file with
             | Some spec_json_file ->
                 let%bind json = Reader.file_contents spec_json_file in
                 return @@ spec_of_json json
             | None -> (
                 return
                 @@
                 match spec_sexp with
                 | Some spec ->
                     One_or_two.t_of_sexp
                       (Work.Work.Single.Spec.t_of_sexp
                          Transaction_witness.Stable.Latest.t_of_sexp
                          Ledger_proof.t_of_sexp )
                       (Sexp.of_string spec)
                 | None ->
                     failwith "Provide a spec either in json or sexp format" ) )
       in
       let fee =
         Option.value
           ~default:(Currency.Fee.of_nanomina_int_exn 10)
           snark_work_fee
       in
       let spec =
         Work.Partitioned.Spec.Poly.Old
           { instances =
               One_or_two.map
                 ~f:(fun i ->
                   ( Work.Selector.Single.Spec.write_all_proofs_to_disk
                       ~proof_cache_db i
                   , () ) )
                 spec
           ; fee
           }
       in
       let public_key =
         Option.value
           ~default:(fst Key_gen.Sample_keypairs.genesis_winner)
           snark_worker_key
       in

       let message = Mina_base.Sok_message.create ~fee ~prover:public_key in
       let sok_digest = Mina_base.Sok_message.digest message in
       match%bind
         Snark_worker.Impl.Prod.perform ~state:worker_state ~sok_digest ~spec
       with
       | Ok (Work.Partitioned.Spec.Poly.Single _)
       | Ok (Work.Partitioned.Spec.Poly.Sub_zkapp_command _) ->
           Caml.Format.printf !"Result type is not old, unexpected" ;
           exit 1
       | Ok (Work.Partitioned.Spec.Poly.Old { instances; fee }) -> (
           let extract_proof (_, Work.Partitioned.Proof_with_metric.{ proof; _ })
               =
             Ledger_proof.Cached.read_proof_from_disk proof
           in
           let extract_statement ((spec : Work.Selector.Single.Spec.t), _) =
             Work.Work.Single.Spec.statement spec
           in
           let result =
             Work.Work.Result_without_metrics.
               { proofs = One_or_two.map ~f:extract_proof instances
               ; statements = One_or_two.map ~f:extract_statement instances
               ; prover = public_key
               ; fee
               }
           in
           Caml.Format.printf
             !"@[<v>Successfully proved. Result: \n\
              \               %{sexp: Ledger_proof.t \
               Work.Work.Result_without_metrics.t}@]@."
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
