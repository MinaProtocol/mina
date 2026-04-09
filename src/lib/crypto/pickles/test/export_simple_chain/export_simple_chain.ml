(** Export a small recursive Pickles fixture for external verifier experiments.

    Invocation:
      dune exec src/lib/crypto/pickles/test/export_simple_chain/export_simple_chain.exe -- <output.json>
*)

open Core_kernel

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Core_kernel.Backtrace.elide := false

open Impls.Step

let () = Snarky_backendless.Snark0.set_eval_constraints true

module Simple_chain = struct
  type _ Snarky_backendless.Request.t +=
    | Prev_input : Field.Constant.t Snarky_backendless.Request.t
    | Proof : Pickles_types.Nat.N1.n Proof.t Snarky_backendless.Request.t

  let handler (prev_input : Field.Constant.t) (proof : _ Proof.t)
      (Snarky_backendless.Request.With { request; respond }) =
    match request with
    | Prev_input ->
        respond (Provide prev_input)
    | Proof ->
        respond (Provide proof)
    | _ ->
        respond Unhandled

  let tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N1)
          ~name:"simple-chain-export"
          ~choices:(fun ~self ->
            [ { identifier = "main"
              ; prevs = [ self ]
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; main =
                  (fun { public_input = self } ->
                    let prev =
                      exists Field.typ ~request:(fun () -> Prev_input)
                    in
                    let proof =
                      exists (Typ.prover_value ()) ~request:(fun () -> Proof)
                    in
                    let is_base_case = Field.equal Field.zero self in
                    let proof_must_verify = Boolean.not is_base_case in
                    let self_correct = Field.(equal (one + prev) self) in
                    Boolean.Assert.any [ self_correct; is_base_case ] ;
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
                          [ { public_input = prev; proof; proof_must_verify } ]
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

type fixture =
    { name : string
    ; statement : Field.Constant.t
    ; side_loaded_proof : Side_loaded.Proof.t
    }

  let generate_fixtures () =
    let s_neg_one = Field.Constant.(negate one) in
    let b_neg_one : Pickles_types.Nat.N1.n Pickles.Proof.t =
      Pickles.Proof.dummy Pickles_types.Nat.N1.n Pickles_types.Nat.N1.n
        ~domain_log2:14
    in
    let (), (), b0 =
      Common.time "b0" (fun () ->
          Promise.block_on_async_exn (fun () ->
              step ~handler:(handler s_neg_one b_neg_one) Field.Constant.zero ) )
    in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
    let (), (), b1 =
      Common.time "b1" (fun () ->
          Promise.block_on_async_exn (fun () ->
              step ~handler:(handler Field.Constant.zero b0) Field.Constant.one ) )
    in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (Field.Constant.one, b1) ] ) ) ;
    [ { name = "base_case"
      ; statement = Field.Constant.zero
      ; side_loaded_proof = Side_loaded.Proof.of_proof b0
      }
    ; { name = "recursive_step"
      ; statement = Field.Constant.one
      ; side_loaded_proof = Side_loaded.Proof.of_proof b1
      }
    ]
end

let field_json (x : Field.Constant.t) = `String (Field.Constant.to_string x)

let statement_fields_json (statement : Field.Constant.t) = `List [ field_json statement ]

let fixture_json ({ Simple_chain.name; statement; side_loaded_proof } :
                  Simple_chain.fixture ) =
  `Assoc
    [ ("name", `String name)
    ; ("statement", field_json statement)
    ; ("statement_fields", statement_fields_json statement)
    ; ("side_loaded_proof_base64", `String (Side_loaded.Proof.to_base64 side_loaded_proof))
    ; ( "rust_inputs"
      , `Assoc
          [ ("statement_field_strings", statement_fields_json statement)
          ; ( "side_loaded_proof_base64"
            , `String (Side_loaded.Proof.to_base64 side_loaded_proof) )
          ] )
    ]

let export_json fixtures ~(side_loaded_vk : Side_loaded.Verification_key.t) =
  `Assoc
    [ ("schema_version", `Int 1)
    ; ("proof_system", `String "pickles-simple-chain")
    ; ("statement_kind", `String "single_tick_field")
    ; ( "side_loaded_verification_key_base64"
      , `String (Side_loaded.Verification_key.to_base64 side_loaded_vk) )
    ; ( "rust_bundle"
      , `Assoc
          [ ("bundle_version", `Int 1)
          ; ( "side_loaded_verification_key_base64"
            , `String (Side_loaded.Verification_key.to_base64 side_loaded_vk) )
          ; ("fixtures", `List (List.map fixtures ~f:fixture_json))
          ] )
    ; ("fixtures", `List (List.map fixtures ~f:fixture_json))
    ]

let write_json path json =
  let oc = Out_channel.create path in
  Exn.protect
    ~finally:(fun () -> Out_channel.close oc)
    ~f:(fun () ->
      Yojson.Safe.pretty_to_channel oc json ;
      Out_channel.newline oc)

let write_string path contents = Out_channel.write_all path ~data:contents

let manifest_stem path =
  try Filename.chop_extension path with _ -> path

let write_rust_bundle_files output_path
    (fixtures : Simple_chain.fixture list)
    ~(side_loaded_vk : Side_loaded.Verification_key.t) =
  let stem = manifest_stem output_path in
  write_string
    (stem ^ ".side_loaded_vk.base64")
    (Side_loaded.Verification_key.to_base64 side_loaded_vk ^ "\n") ;
  List.iter fixtures ~f:(fun { name; statement; side_loaded_proof } ->
      let prefix = stem ^ "." ^ name in
      write_json
        (prefix ^ ".statement_fields.json")
        (statement_fields_json statement) ;
      write_string
        (prefix ^ ".side_loaded_proof.base64")
        (Side_loaded.Proof.to_base64 side_loaded_proof ^ "\n"))

let () =
  match Sys.argv with
  | [| _; output_path |] ->
      let fixtures = Simple_chain.generate_fixtures () in
      let side_loaded_vk =
        Promise.block_on_async_exn (fun () ->
            Side_loaded.Verification_key.of_compiled_promise Simple_chain.tag )
      in
      write_json output_path (export_json fixtures ~side_loaded_vk) ;
      write_rust_bundle_files output_path fixtures ~side_loaded_vk
  | argv ->
      eprintf "usage: %s <output.json>\n%!" argv.(0) ;
      Stdlib.exit 1
