open Core_kernel
open Pickles_types
open Composition_types
open Kimchi_pasta_snarky_backend.Step_impl

(* Dump Spec.pack output AND compute x_hat for specific field values.
   Uses Field.of_int to create distinct constants so we can trace
   the exact contribution of each entry to x_hat. *)
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
  let fv i = Field.of_int i in
  let sc i = Kimchi_backend_common.Scalar_challenge.create (fv i) in
  let sv i = Shifted_value.Type1.Shifted_value (fv i) in
  let bp i = Bulletproof_challenge.{ prechallenge = sc i } in
  let bd = Branch_data.Checked.Step.{
    proofs_verified_mask = Vector.[ Boolean.false_; Boolean.false_ ] ;
    domain_log2 = fv 999
  } in
  let feature_flags_var =
    Plonk_types.Features.map feature_flags_bool ~f:(fun _ -> Boolean.false_)
  in
  let bp_vec = Vector.init Backend.Tick.Rounds.n ~f:(fun i -> bp (501 + i)) in
  let statement_data =
    Wrap.Statement.In_circuit.to_data
      { proof_state =
          { deferred_values =
              { plonk =
                  { alpha = sc 301; beta = fv 201; gamma = fv 202; zeta = sc 302
                  ; zeta_to_srs_length = sv 102; zeta_to_domain_size = sv 103
                  ; perm = sv 104; feature_flags = feature_flags_var
                  ; joint_combiner = Opt.nothing }
              ; xi = sc 303; combined_inner_product = sv 101; b = sv 105
              ; bulletproof_challenges = bp_vec; branch_data = bd }
          ; sponge_digest_before_evaluations = fv 401
          ; messages_for_next_wrap_proof = fv 402 }
      ; messages_for_next_step_proof = fv 403 }
      ~option_map:Opt.map
  in
  let packed =
    Spec.pack
      (module Kimchi_pasta_snarky_backend.Step_impl)
      (module Branch_data.Checked.Step)
      spec
      statement_data
    (* Strip Type1 wrappers like step_verifier.ml:1260-1264 *)
    |> Array.map ~f:(function
         | `Field (Shifted_value.Type1.Shifted_value x) -> `Field x
         | `Packed_bits (x, n) -> `Packed_bits (x, n) )
  in
  printf "Total entries: %d\n" (Array.length packed) ;
  printf "\nField values (non-constant entries for publicInputCommit):\n" ;
  let non_const_count = ref 0 in
  Array.iteri packed ~f:(fun i entry ->
      let value, kind, is_const =
        match entry with
        | `Field (Constant c) -> (c, "Field(255)", true)
        | `Field _ -> (Field.Constant.zero, "Field(255)", false)
        | `Packed_bits (Constant c, n) -> (c, sprintf "PB(%d)" n, true)
        | `Packed_bits (_, n) -> (Field.Constant.zero, sprintf "PB(%d)" n, false)
      in
      if is_const then
        printf "  [%2d] %-10s const=%s\n" i kind (Kimchi_pasta_basic.Fp.to_string value)
      else begin
        printf "  [%2d] %-10s <var> (lagrange base %d)\n" i kind !non_const_count ;
        incr non_const_count
      end ) ;
  printf "\nNon-constant entries (consume lagrange bases): %d\n" !non_const_count ;
  printf "Constant entries (folded into correction): %d\n"
    (Array.length packed - !non_const_count)
