(* Executable demonstrating a Simple_chain recursive proof with a
   parameterized initial state.

   The public input of each proof is a pair [(initial, current)]. The base
   case requires [current = initial] (so any anchor works, not just zero).
   Every recursive step asserts both [prev_current + 1 = current] and
   [prev_initial = initial], so the anchor is carried through the chain and
   cannot be rewritten. *)

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Core_kernel.Backtrace.elide := false

open Impls.Step

let () = Snarky_backendless.Snark0.set_eval_constraints true

module Simple_chain = struct
  type _ Snarky_backendless.Request.t +=
    | Prev_input :
        (Field.Constant.t * Field.Constant.t) Snarky_backendless.Request.t
    | Proof : Pickles_types.Nat.N1.n Proof.t Snarky_backendless.Request.t

  let handler (prev_input : Field.Constant.t * Field.Constant.t)
      (proof : _ Proof.t) (Snarky_backendless.Request.With { request; respond })
      =
    match request with
    | Prev_input ->
        respond (Provide prev_input)
    | Proof ->
        respond (Provide proof)
    | _ ->
        respond Unhandled

  let _tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise ()
          ~public_input:(Input (Typ.tuple2 Field.typ Field.typ))
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N1)
          ~name:"blockchain-snark"
          ~choices:(fun ~self ->
            [ { identifier = "main"
              ; prevs = [ self ]
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; main =
                  (fun { public_input = initial, current } ->
                    let prev_initial, prev_current =
                      exists (Typ.tuple2 Field.typ Field.typ)
                        ~request:(fun () -> Prev_input)
                    in
                    let proof =
                      exists (Typ.prover_value ()) ~request:(fun () -> Proof)
                    in
                    let is_base_case = Field.equal current initial in
                    let proof_must_verify = Boolean.not is_base_case in
                    let step_ok = Field.(equal (one + prev_current) current) in
                    let carry_ok = Field.equal prev_initial initial in
                    Boolean.Assert.any [ step_ok; is_base_case ] ;
                    Boolean.Assert.any [ carry_ok; is_base_case ] ;
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
                          [ { public_input = (prev_initial, prev_current)
                            ; proof
                            ; proof_must_verify
                            }
                          ]
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)
end

(* Truncate/create the file so that the kimchi bindings' [write] (which uses
   [OpenOptions::new().append(true).open(path)]) doesn't fail for a
   non-existent file and doesn't append onto stale bytes from a prior run. *)
let truncate_or_create path =
  Core_kernel.Out_channel.close (Core_kernel.Out_channel.create path)

(* All emission helpers below are gated on [SIMPLE_CHAIN_FIXTURES_DIR].
   When set, this directory is the single output root for every fixture:
   wrap VI/SRS (shared across iterations), and per-iteration
   `proof_repr_b{N}.json`. *)
let fixtures_dir () = Sys.getenv_opt "SIMPLE_CHAIN_FIXTURES_DIR"

let path_in_dir dir name = Filename.concat dir name

let emit_wrap_vi_if_requested ~(pickles_vk : Pickles.Verification_key.t) =
  match fixtures_dir () with
  | None ->
      ()
  | Some dir ->
      let path = path_in_dir dir "simple_chain_wrap_vi.bin" in
      truncate_or_create path ;
      let index = Pickles.Verification_key.index pickles_vk in
      Kimchi_bindings.Protocol.VerifierIndex.Fq.write (Some true) index path ;
      Format.printf "wrote wrap VI (msgpack) to %s@." path

let emit_wrap_srs_if_requested ~(pickles_vk : Pickles.Verification_key.t) =
  match fixtures_dir () with
  | None ->
      ()
  | Some dir ->
      let path = path_in_dir dir "simple_chain_wrap_srs.bin" in
      truncate_or_create path ;
      let index = Pickles.Verification_key.index pickles_vk in
      Kimchi_bindings.Protocol.SRS.Fq.write (Some true) index.srs path ;
      Format.printf "wrote wrap SRS (msgpack) to %s@." path

(* Splice [app_state] into a proof-Repr JSON at
   [statement.messages_for_next_step_proof.app_state] (which pickles writes as
   [null] because its stored [Proof.t] fixes ['s = unit]). The splice replaces
   that [null] with an array of decimal strings, one per field element. *)
let inject_app_state ~(fields : Impls.Step.Field.Constant.t array)
    (json : Yojson.Safe.t) : Yojson.Safe.t =
  let app_state_json : Yojson.Safe.t =
    `List
      (Array.to_list
         (Array.map fields ~f:(fun f ->
              `String (Impls.Step.Field.Constant.to_string f) ) ) )
  in
  let update_obj key f = function
    | `Assoc fields ->
        `Assoc
          (List.map fields ~f:(fun (k, v) ->
               if String.equal k key then (k, f v) else (k, v) ) )
    | j ->
        j
  in
  json
  |> update_obj "statement"
       (update_obj "messages_for_next_step_proof"
          (update_obj "app_state" (fun _ -> app_state_json)) )

(* When [SIMPLE_CHAIN_FIXTURES_DIR] is set, dump the pickles
   [Proof.Repr.t] for [pickles_proof] as JSON at
   `${dir}/simple_chain_proof_repr_b{idx}.json`, using pickles' own
   ppx-derived yojson serializer, and splice the real app-state field
   elements into [statement.messages_for_next_step_proof.app_state] in
   place of the [null] that the raw pickles dump emits. *)
let emit_proof_repr_json_if_requested ~idx
    ~(pickles_proof : Pickles_types.Nat.N1.n Pickles.Proof.t)
    ~(app_state : Impls.Step.Field.Constant.t array) =
  match fixtures_dir () with
  | None ->
      ()
  | Some dir ->
      let path =
        path_in_dir dir (Printf.sprintf "simple_chain_proof_repr_b%d.json" idx)
      in
      let module Proof_N1 = Pickles.Proof.Make (Pickles_types.Nat.N1) in
      let json = Proof_N1.to_yojson_full pickles_proof in
      let json = inject_app_state ~fields:app_state json in
      Yojson.Safe.to_file path json ;
      Format.printf "wrote pickles proof Repr (JSON) to %s@." path

(* Build a recursive step: assert prev_input matches the statement's
   carried (initial, current_minus_one) and produce a proof for
   (initial, current). *)
let prove_step ~label ~prev_input ~prev_proof ~initial ~current =
  let (), (), proof =
    Common.time label (fun () ->
        Promise.block_on_async_exn (fun () ->
            Simple_chain.step
              ~handler:(Simple_chain.handler prev_input prev_proof)
              (initial, current) ) )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Simple_chain.Proof.verify_promise [ ((initial, current), proof) ] ) ) ;
  Format.printf "[%s] proof verified, (initial, current) = (%s, %s)@." label
    (Field.Constant.to_string initial)
    (Field.Constant.to_string current) ;
  proof

let () =
  let initial = Field.Constant.of_int 41 in
  let f n = Field.Constant.of_int (41 + n) in

  (* Base case: (initial=41, current=41). The previous-proof slot is a dummy
     that is not required to verify, because [current = initial] here. *)
  let dummy_prev_input =
    (Field.Constant.(negate one), Field.Constant.(negate one))
  in
  let dummy_prev_proof : Pickles_types.Nat.N1.n Pickles.Proof.t =
    Pickles.Proof.dummy Pickles_types.Nat.N1.n Pickles_types.Nat.N1.n
      ~domain_log2:14
  in
  let base_case =
    prove_step ~label:"base_case" ~prev_input:dummy_prev_input
      ~prev_proof:dummy_prev_proof ~initial ~current:initial
  in
  (* Chain depth: emit four non-base proofs b0..b3 stepping through
     (41,42), (41,43), (41,44), (41,45). Each bN feeds bN+1 as
     [prev_proof]. *)
  let b0 =
    prove_step ~label:"b0" ~prev_input:(initial, initial) ~prev_proof:base_case
      ~initial ~current:(f 1)
  in
  let b1 =
    prove_step ~label:"b1"
      ~prev_input:(initial, f 1)
      ~prev_proof:b0 ~initial ~current:(f 2)
  in
  let b2 =
    prove_step ~label:"b2"
      ~prev_input:(initial, f 2)
      ~prev_proof:b1 ~initial ~current:(f 3)
  in
  let b3 =
    prove_step ~label:"b3"
      ~prev_input:(initial, f 3)
      ~prev_proof:b2 ~initial ~current:(f 4)
  in

  let pickles_vk : Pickles.Verification_key.t =
    Promise.block_on_async_exn (fun () ->
        Lazy.force Simple_chain.Proof.verification_key_promise )
  in
  emit_wrap_vi_if_requested ~pickles_vk ;
  emit_wrap_srs_if_requested ~pickles_vk ;
  let emit ~idx ~proof ~current =
    emit_proof_repr_json_if_requested ~idx ~pickles_proof:proof
      ~app_state:[| initial; current |]
  in
  emit ~idx:0 ~proof:b0 ~current:(f 1) ;
  emit ~idx:1 ~proof:b1 ~current:(f 2) ;
  emit ~idx:2 ~proof:b2 ~current:(f 3) ;
  emit ~idx:3 ~proof:b3 ~current:(f 4)
