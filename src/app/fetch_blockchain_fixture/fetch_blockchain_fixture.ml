(** Download the blockchain SNARK verification key + the latest proof from a
    running mina daemon's GraphQL endpoint and write a pickles-verifier fixture.

    Outputs (into <output-dir>):
    - vk.serde.json              : kimchi wrap [VerifierIndex] (Rust serde JSON)
    - proof.serde.json           : kimchi wrap [ProverProof]   (Rust serde JSON)
    - public_input_skeleton.json : pickles [{ statement; prev_evals }] (proof omitted)
    - app_statement.json         : the blockchain public input (= protocol state hash)

    Both the proof and the verification key are fetched from the same deployed
    node (the VK via [blockchainVerificationKey]), so they are guaranteed to
    match and no circuit compilation / SRS / profile selection is needed. The
    serde projection mirrors [dump_*_fixtures.ml].

    Endpoint via env: MINA_GRAPHQL_URI (a full URL), or MINA_GRAPHQL_HOST plus an
    optional MINA_GRAPHQL_PORT (default 3085). *)

open Core
open Async
module Nat = Pickles_types.Nat
module Vector = Pickles_types.Vector

(* ---- GraphQL fetch (reuses the existing typed client; result parsed raw) ---- *)

let fetch ~uri =
  let query_obj =
    Mina_graphql_client.Queries.Block_proof.(
      make @@ makeVariables ~max_length:1 ())
  in
  match%map Graphql_lib.Client.query_json query_obj uri with
  | Error (`Failed_request e) ->
      failwithf "GraphQL request to %s failed: %s" (Uri.to_string uri) e ()
  | Error (`Graphql_error e) ->
      failwithf "GraphQL error: %s" e ()
  | Ok data ->
      let open Yojson.Safe.Util in
      let vk_json = member "blockchainVerificationKey" data in
      ( match vk_json with
      | `Null ->
          failwith "response has no blockchainVerificationKey"
      | _ ->
          () ) ;
      let block =
        match data |> member "bestChain" |> to_list with
        | b :: _ ->
            b
        | [] ->
            failwith "bestChain returned no blocks"
      in
      let base64 =
        block |> member "protocolStateProof" |> member "base64" |> to_string
      in
      let state_hash_decimal = block |> member "stateHashField" |> to_string in
      (vk_json, base64, state_hash_decimal)

(* ---- Projection to the serde fixture format (mirrors dump_*_fixtures.ml) ---- *)

let write_fixture ~output_dir ~(vk : Pickles.Verification_key.t)
    ~(proof : Nat.N2.n Pickles.Proof.t) ~state_hash_decimal =
  Core_unix.mkdir_p output_dir ;
  (* verification key *)
  let vk_serde =
    Kimchi_bindings.Protocol.VerifierIndex.Fq.to_serde_json
      (Pickles.Verification_key.index vk)
  in
  Out_channel.write_all (output_dir ^ "/vk.serde.json") ~data:vk_serde ;
  (* wrap proof: same serde extraction as the dumpers (max_proofs_verified = N2) *)
  let b_concrete : Nat.N2.n Mina_wire_types.Pickles.Concrete_.Proof.t =
    Obj.magic proof
  in
  let (Mina_wire_types.Pickles.Concrete_.Proof.T b_inner) = b_concrete in
  let chal_polys =
    Pickles.Wrap_hack.pad_accumulator
      (Vector.map2
         ~f:(fun g cs ->
           { Pickles.Backend.Tock.Proof.Challenge_polynomial.challenges =
               Vector.to_array (Pickles.Common.Ipa.Wrap.compute_challenges cs)
           ; commitment = g
           } )
         (Vector.extend_front_exn
            b_inner.statement.messages_for_next_step_proof
              .challenge_polynomial_commitments Nat.N2.n
            (Lazy.force Pickles.Dummy.Ipa.Wrap.sg) )
         b_inner.statement.proof_state.messages_for_next_wrap_proof
           .old_bulletproof_challenges )
  in
  let kimchi_proof = Pickles.Wrap_wire_proof.to_kimchi_proof b_inner.proof in
  let with_pe : Pickles.Backend.Tock.Proof.with_public_evals =
    { proof = kimchi_proof; public_evals = None }
  in
  let backend_proof =
    Pickles.Backend.Tock.Proof.to_backend_with_public_evals' chal_polys [||]
      with_pe
  in
  let proof_json =
    Kimchi_bindings.Protocol.Proof.Fq.to_serde_json backend_proof
  in
  Out_channel.write_all (output_dir ^ "/proof.serde.json") ~data:proof_json ;
  (* pickles statement skeleton: { statement; prev_evals }, proof field dropped *)
  let module ProofM = Pickles.Proof.Make (Nat.N2) in
  let skeleton =
    match ProofM.to_yojson_full proof with
    | `Assoc kvs ->
        `Assoc (List.filter kvs ~f:(fun (k, _) -> not (String.equal k "proof")))
    | other ->
        other
  in
  Out_channel.write_all
    (output_dir ^ "/public_input_skeleton.json")
    ~data:(Yojson.Safe.to_string skeleton) ;
  (* app statement = blockchain public input = protocol state hash (1 field).
     Snark_params.Tick.Field.to_yojson = Kimchi_pasta_basic.Fp.to_yojson, i.e.
     byte-identical to the dumpers' Backend.Tick.Field.to_yojson. *)
  let state_hash = Snark_params.Tick.Field.of_string state_hash_decimal in
  Out_channel.write_all
    (output_dir ^ "/app_statement.json")
    ~data:(Yojson.Safe.to_string (Snark_params.Tick.Field.to_yojson state_hash))

(* ---- Main ---- *)

let run ~uri ~output_dir =
  eprintf "Fetching blockchain VK + latest proof from %s ...\n%!"
    (Uri.to_string uri) ;
  let%bind vk_json, base64, state_hash_decimal = fetch ~uri in
  let vk =
    match Pickles.Verification_key.of_yojson vk_json with
    | Ok vk ->
        vk
    | Error e ->
        failwithf "blockchainVerificationKey of_yojson failed: %s" e ()
  in
  let proof = Mina_block.Precomputed.Proof.of_bin_string base64 in
  write_fixture ~output_dir ~vk ~proof ~state_hash_decimal ;
  eprintf "Wrote fixture to %s\n%!" output_dir ;
  return ()

(* The GraphQL endpoint is read from the environment (keeps the node address out
   of argv): either MINA_GRAPHQL_URI (a full URL) or MINA_GRAPHQL_HOST plus an
   optional MINA_GRAPHQL_PORT (default 3085). *)
let uri_from_env () =
  match Sys.getenv "MINA_GRAPHQL_URI" with
  | Some s ->
      Uri.of_string s
  | None -> (
      match Sys.getenv "MINA_GRAPHQL_HOST" with
      | None ->
          eprintf
            "error: set MINA_GRAPHQL_URI, or MINA_GRAPHQL_HOST (and optionally \
             MINA_GRAPHQL_PORT)\n" ;
          Stdlib.exit 1
      | Some host ->
          let port =
            match Sys.getenv "MINA_GRAPHQL_PORT" with
            | Some p ->
                Int.of_string p
            | None ->
                3085
          in
          Uri.make ~scheme:"http" ~host ~port ~path:"/graphql" () )

let () =
  let output_dir = ref "fixtures/mainnet-blockchain-snark" in
  let spec =
    [ ( "-output-dir"
      , Stdlib.Arg.Set_string output_dir
      , "DIR output directory (default fixtures/mainnet-blockchain-snark)" )
    ]
  in
  Stdlib.Arg.parse spec
    (fun _ -> ())
    "fetch_blockchain_fixture [-output-dir DIR]  (endpoint via \
     MINA_GRAPHQL_URI or MINA_GRAPHQL_HOST[/_PORT])" ;
  let uri = uri_from_env () in
  Async.Thread_safe.block_on_async_exn (fun () ->
      run ~uri ~output_dir:!output_dir )
