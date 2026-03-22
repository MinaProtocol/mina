open Core_kernel
open Pickles_types
open Composition_types
open Kimchi_pasta_snarky_backend.Step_impl

let () =
  let feature_flags = Plonk_types.Features.none_bool in
  let feature_flags_full =
    Plonk_types.Features.map feature_flags ~f:(fun b ->
        if b then Opt.Flag.Yes else Opt.Flag.No )
  in
  let lookup_parameters : _ Wrap.Lookup_parameters.t =
    { use = No
    ; zero =
        { var = { challenge = Field.zero; scalar = Shifted_value.Type1.Shifted_value Field.zero }
        ; value =
            { challenge = Limb_vector.Challenge.Constant.zero
            ; scalar = Shifted_value.Type1.Shifted_value Field.Constant.zero
            }
        }
    }
  in
  let spec =
    Wrap.Statement.In_circuit.spec
      (module Kimchi_pasta_snarky_backend.Step_impl)
      lookup_parameters
      feature_flags_full
  in
  (* Create minimal dummy statement data *)
  let f = Field.zero in
  let c = Limb_vector.Challenge.Constant.zero in
  let sc = Kimchi_backend_common.Scalar_challenge.create c in
  let sv x = Shifted_value.Type1.Shifted_value x in
  let bp = Bulletproof_challenge.{ prechallenge = sc } in
  let bd = Branch_data.{ proofs_verified = Pickles_base.Proofs_verified.N0
                       ; domain_log2 = Branch_data.Domain_log2.of_int_exn 15 } in
  let bp_vec = Vector.init Backend.Tick.Rounds.n ~f:(fun _ -> bp) in
  let statement_data =
    Wrap.Statement.In_circuit.to_data
      { proof_state =
          { deferred_values =
              { plonk =
                  { alpha = sc; beta = c; gamma = c; zeta = sc
                  ; zeta_to_srs_length = sv f; zeta_to_domain_size = sv f
                  ; perm = sv f; feature_flags; joint_combiner = None }
              ; xi = sc; combined_inner_product = sv f; b = sv f
              ; bulletproof_challenges = bp_vec; branch_data = bd }
          ; sponge_digest_before_evaluations = Field.Constant.zero
          ; messages_for_next_wrap_proof = Field.Constant.zero }
      ; messages_for_next_step_proof = Field.Constant.zero }
      ~option_map:Option.map
  in
  let packed =
    Spec.pack
      (module Kimchi_pasta_snarky_backend.Step_impl)
      (module Branch_data.Checked.Step)
      spec
      statement_data
  in
  printf "Total entries from Spec.pack: %d\n" (Array.length packed) ;
  Array.iteri packed ~f:(fun i entry ->
      match entry with
      | `Field _ -> printf "  [%2d] Field (255-bit)\n" i
      | `Packed_bits (_, n) -> printf "  [%2d] Packed_bits(%d)\n" i n )
