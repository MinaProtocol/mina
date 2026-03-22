open Core_kernel
open Pickles_types
open Composition_types
open Kimchi_pasta_snarky_backend.Step_impl

let () =
  let feature_flags_bool = Plonk_types.Features.none_bool in
  let feature_flags_opt =
    Plonk_types.Features.map feature_flags_bool ~f:(fun b ->
        if b then Opt.Flag.Yes else Opt.Flag.No )
  in
  let lookup_parameters : _ Wrap.Lookup_parameters.t =
    { use = No
    ; zero =
        { var = { challenge = Field.zero
                ; scalar = Shifted_value.Type1.Shifted_value Field.zero }
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
      feature_flags_opt
  in
  (* Use field_var (circuit variable) types, not constants *)
  let fv = Field.zero in  (* field_var *)
  let sc = Kimchi_backend_common.Scalar_challenge.create fv in
  let sv = Shifted_value.Type1.Shifted_value fv in
  let bp = Bulletproof_challenge.{ prechallenge = sc } in
  let bd = Branch_data.Checked.Step.{
    proofs_verified_mask = Vector.[ Boolean.false_; Boolean.false_ ] ;
    domain_log2 = fv
  } in
  let feature_flags_var =
    Plonk_types.Features.map feature_flags_bool ~f:(fun _ -> Boolean.false_)
  in
  let bp_vec = Vector.init Backend.Tick.Rounds.n ~f:(fun _ -> bp) in
  let statement_data =
    Wrap.Statement.In_circuit.to_data
      { proof_state =
          { deferred_values =
              { plonk =
                  { alpha = sc; beta = fv; gamma = fv; zeta = sc
                  ; zeta_to_srs_length = sv; zeta_to_domain_size = sv
                  ; perm = sv; feature_flags = feature_flags_var
                  ; joint_combiner = Opt.nothing }
              ; xi = sc; combined_inner_product = sv; b = sv
              ; bulletproof_challenges = bp_vec; branch_data = bd }
          ; sponge_digest_before_evaluations = fv
          ; messages_for_next_wrap_proof = fv }
      ; messages_for_next_step_proof = fv }
      ~option_map:Opt.map
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
