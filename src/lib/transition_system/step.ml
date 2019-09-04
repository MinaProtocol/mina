open Core
open Fold_lib
open Snark_params
open Bitstring_lib
open Tick
open Run

let ( ! ) = run_checked

let pad_to_triples = Bitstring.pad_to_triple_list ~default:Boolean.false_

module Witness = struct
  type ('state, 'update) t =
    {proof: Tock.Proof.t; previous_state: 'state; update: 'update}
end

let input_size = Step_input.size

module Verification_keys = struct
  type t =
    { wrap_vk: Wrap_vk_compressed.Unchecked.t
    ; step_vk: Step_vk_compressed.Unchecked.t
    ; hash_state: Pedersen.State.t }

  let create ~wrap_vk ~step_vk =
    let wrap_vk = Wrap_vk_compressed.Unchecked.of_backend_vk wrap_vk in
    let step_vk = Step_vk_compressed.Unchecked.of_backend_vk step_vk in
    let hash_state =
      let wrap_vk_bits =
        Wrap_vk_compressed.to_bits wrap_vk ~unpack_field:(fun t ~length ->
            List.take (Tick.Field.unpack t) length )
      and step_vk_bits =
        Step_vk_compressed.to_bits step_vk ~unpack_field:(fun t ~length ->
            List.take (Tock.Field.unpack t) length )
      in
      Pedersen.State.update_fold Hash_prefix_states.transition_system_snark
        Fold.(
          group3 ~default:false (of_list wrap_vk_bits +> of_list step_vk_bits))
    in
    {wrap_vk; step_vk; hash_state}
end

module Make (Inputs : Intf.Step_inputs_intf) = struct
  open Inputs

  module Witness = struct
    type t = (State.Unchecked.t, Update.Unchecked.t) Witness.t
  end

  (* Returns the function that computes

   fun state_hash -> hash(wrap_vk || step_vk || state_hash) *)
  let to_instance_hash ~wrap_vk_compressed ~step_vk_compressed =
    let open Pedersen.Checked in
    let vks =
      let wrap_vk_bits =
        Wrap_vk_compressed.to_bits ~unpack_field:Field.choose_preimage_var
          wrap_vk_compressed
      and step_vk_bits =
        Tock.Verifier.Verification_key.Compressed.to_list step_vk_compressed
        |> List.concat
      in
      !(Section.append
          (hash_prefix Hash_prefix_states.transition_system_snark)
          (pad_to_triples (wrap_vk_bits @ step_vk_bits)))
    in
    stage (fun s ->
        !(Section.append vks (State.Hash.to_triples s))
        |> Section.to_initial_segment_digest_exn |> fst )

  let instance_hash {Verification_keys.hash_state; _} s =
    Pedersen.digest_fold hash_state
      (State.Hash.Unchecked.fold (State.Unchecked.hash s))

  (* Return the function that computes

   fun x proof -> verify_wrap (step_vk, x) proof *)
  let verify_wrap ~wrap_vk_compressed ~step_vk_compressed =
    let wrap_vk =
      !(Verifier.Verification_key.Compressed.decompress wrap_vk_compressed)
    and step_vk = Step_vk_compressed.to_scalars step_vk_compressed in
    let pc = !(Verifier.Verification_key.Precomputation.create wrap_vk) in
    stage (fun x proof ->
        !(let%bind x = Wrap_input.Checked.tick_field_to_scalars x in
          Verifier.verify wrap_vk pc (step_vk @ x) proof) )

  let verify_wrap =
    match Coda_compile_config.proof_level with
    | "full" ->
        verify_wrap
    | "check" | "none" ->
        fun ~wrap_vk_compressed:_ ~step_vk_compressed:_ ->
          stage (fun _ _ -> Boolean.true_)
    | _ ->
        failwith "unknown proof_level"

  include struct
    open Snarky.Request

    type _ t +=
      | Wrap_vk : Wrap_vk_compressed.Unchecked.t t
      | Previous_state : State.Unchecked.t t
      | Step_vk : Step_vk_compressed.Unchecked.t t
      | Proof : (Inner_curve.t, Pairing.G2.Unchecked.t) Verifier.Proof.t_ t
      | Update : Update.Unchecked.t t
  end

  let main (h : Field.t) =
    let verify, to_top_hash =
      let wrap_vk_compressed =
        exists Wrap_vk_compressed.typ ~request:(fun () -> Wrap_vk)
      and step_vk_compressed =
        exists Step_vk_compressed.typ ~request:(fun () -> Step_vk)
      in
      ( unstage (verify_wrap ~wrap_vk_compressed ~step_vk_compressed)
      , unstage (to_instance_hash ~wrap_vk_compressed ~step_vk_compressed) )
    in
    let previous_state =
      exists State.typ ~request:(fun () -> Previous_state)
    in
    let previous_state_hash = State.hash previous_state in
    let previous_state_valid =
      let pi = exists Verifier.Proof.typ ~request:(fun () -> Proof) in
      verify (to_top_hash previous_state_hash) pi
    in
    let update = exists Update.typ ~request:(fun () -> Update) in
    let next_state_hash, next_state, `Success update_succeeded =
      State.update (previous_state_hash, previous_state) update
    in
    let next_top_hash = to_top_hash next_state_hash in
    Field.Assert.equal h next_top_hash ;
    Boolean.(
      Assert.any
        [ previous_state_valid && update_succeeded
        ; State.Hash.is_base next_state_hash ]) ;
    (next_state, next_top_hash)

  let make_handler ~(wrap_vk : Wrap_vk_compressed.Unchecked.t)
      ~(step_vk : Step_vk_compressed.Unchecked.t)
      ({proof; previous_state; update} : Witness.t) : Handler.t =
   fun (With {request; respond}) ->
    let provide x = respond (Provide x) in
    match request with
    | Wrap_vk ->
        provide wrap_vk
    | Step_vk ->
        provide step_vk
    | Proof ->
        provide (Verifier.proof_of_backend_proof proof)
    | Previous_state ->
        provide previous_state
    | Update ->
        provide update
    | _ ->
        unhandled

  let constraint_system () =
    constraint_system ~exposing:Step_input.input (fun x () -> main x |> ignore)

  let check_against_expected_state (expected_state, expected_top_hash)
      (next_state, next_top_hash) =
    let logger = Logger.create () in
    as_prover
      As_prover.(
        fun () ->
          let in_snark_next_state = read State.typ next_state in
          let next_top_hash = read Field.typ next_top_hash in
          let updated = State.Unchecked.sexp_of_t in_snark_next_state in
          let original = State.Unchecked.sexp_of_t expected_state in
          if not (Field.Constant.equal next_top_hash expected_top_hash) then
            let diff = Sexp_diff_kernel.Algo.diff ~original ~updated () in
            Logger.fatal logger
              "Out-of-SNARK and in-SNARK calculations of the next top hash \
               differ"
              ~metadata:
                [ ( "state_sexp_diff"
                  , `String
                      (Sexp_diff_kernel.Display.display_as_plain_string diff)
                  ) ]
              ~location:__LOC__ ~module_:__MODULE__)

  let handled_main ?(handler = fun _ -> unhandled) vks expected_next_state
      witness =
    let top_hash = instance_hash vks expected_next_state in
    let main x () =
      let next_state = main x in
      check_against_expected_state (expected_next_state, top_hash) next_state
    in
    let main x () =
      handle
        (fun () ->
          handle (main x)
            (make_handler ~wrap_vk:vks.wrap_vk ~step_vk:vks.step_vk witness) )
        handler
    in
    (top_hash, main)

  let check_constraints ?handler vks expected_next_state witness =
    let top_hash, main =
      handled_main ?handler vks expected_next_state witness
    in
    check (main (Field.constant top_hash)) ()

  let prove ?handler vks pk expected_next_state witness =
    let top_hash, main =
      handled_main ?handler vks expected_next_state witness
    in
    Or_error.try_with (fun () ->
        let proof = prove pk Step_input.input main () top_hash in
        (top_hash, proof) )
end
