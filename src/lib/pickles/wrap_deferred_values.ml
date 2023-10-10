module SC = Scalar_challenge
open Core_kernel
open Pickles_types
open Common
open Import
open Backend

(* TODO: Just stick this in plonk_checks.ml *)
module Plonk_checks = struct
  include Plonk_checks
  module Type1 =
    Plonk_checks.Make (Shifted_value.Type1) (Plonk_checks.Scalars.Tick)
end

let expand_deferred (type n most_recent_width)
    ~(evals :
       ( Backend.Tick.Field.t
       , Backend.Tick.Field.t array )
       Pickles_types.Plonk_types.All_evals.t )
    ~(old_bulletproof_challenges :
       ( Challenge.Constant.t Scalar_challenge.Stable.Latest.t
         Bulletproof_challenge.t
         Step_bp_vec.t
       , most_recent_width )
       Pickles_types.Vector.t )
    ~(proof_state :
       ( Challenge.Constant.t
       , Challenge.Constant.t Scalar_challenge.t
       , Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
       , bool
       , n Pickles__.Proof.Base.Messages_for_next_proof_over_same_field.Wrap.t
       , Digest.Constant.t
       , Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
         Step_bp_vec.t
       , Branch_data.t )
       Composition_types.Wrap.Proof_state.Minimal.Stable.V1.t ) :
    _ Types.Wrap.Proof_state.Deferred_values.t =
  let module Tick_field = Backend.Tick.Field in
  let tick_field : _ Plonk_checks.field = (module Tick_field) in
  Timer.start __LOC__ ;
  let open Types.Wrap.Proof_state in
  let sc = SC.to_field_constant tick_field ~endo:Endo.Wrap_inner_curve.scalar in
  Timer.clock __LOC__ ;
  let plonk0 = proof_state.deferred_values.plonk in
  let { Deferred_values.Minimal.branch_data; bulletproof_challenges; _ } =
    Deferred_values.Minimal.map_challenges ~f:Challenge.Constant.to_tick_field
      ~scalar:sc proof_state.deferred_values
  in
  let zeta = sc plonk0.zeta in
  let alpha = sc plonk0.alpha in
  let step_domain = Branch_data.domain branch_data in
  let w =
    Tick.Field.domain_generator ~log2_size:(Domain.log2_size step_domain)
  in
  let zetaw = Tick.Field.mul zeta w in
  let tick_plonk_minimal :
      _ Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.t =
    let chal = Challenge.Constant.to_tick_field in
    { zeta
    ; alpha
    ; beta = chal plonk0.beta
    ; gamma = chal plonk0.gamma
    ; joint_combiner = Option.map ~f:sc plonk0.joint_combiner
    ; feature_flags = plonk0.feature_flags
    }
  in
  let tick_combined_evals =
    Plonk_checks.evals_of_split_evals
      (module Tick.Field)
      evals.evals.evals ~rounds:(Nat.to_int Tick.Rounds.n) ~zeta ~zetaw
    |> Plonk_types.Evals.to_in_circuit
  in
  let tick_domain =
    Plonk_checks.domain
      (module Tick.Field)
      step_domain ~shifts:Common.tick_shifts
      ~domain_generator:Backend.Tick.Field.domain_generator
  in
  let tick_env =
    let module Env_bool = struct
      type t = bool

      let true_ = true

      let false_ = false

      let ( &&& ) = ( && )

      let ( ||| ) = ( || )

      let any = List.exists ~f:Fn.id
    end in
    let module Env_field = struct
      include Tick.Field

      type bool = Env_bool.t

      let if_ (b : bool) ~then_ ~else_ = if b then then_ () else else_ ()
    end in
    Plonk_checks.scalars_env
      (module Env_bool)
      (module Env_field)
      ~endo:Endo.Step_inner_curve.base ~mds:Tick_field_sponge.params.mds
      ~srs_length_log2:Common.Max_degree.step_log2
      ~field_of_hex:(fun s ->
        Kimchi_pasta.Pasta.Bigint256.of_hex_string s
        |> Kimchi_pasta.Pasta.Fp.of_bigint )
      ~domain:tick_domain tick_plonk_minimal tick_combined_evals
  in
  let plonk =
    let p =
      let module Field = struct
        include Tick.Field
      end in
      Plonk_checks.Type1.derive_plonk
        (module Field)
        ~shift:Shifts.tick1 ~env:tick_env tick_plonk_minimal tick_combined_evals
    in
    { p with
      zeta = plonk0.zeta
    ; alpha = plonk0.alpha
    ; beta = plonk0.beta
    ; gamma = plonk0.gamma
    ; joint_combiner = plonk0.joint_combiner
    }
  in
  Timer.clock __LOC__ ;
  let absorb, squeeze =
    let open Tick_field_sponge.Bits in
    let sponge =
      let s = create Tick_field_sponge.params in
      absorb s
        (Digest.Constant.to_tick_field
           proof_state.sponge_digest_before_evaluations ) ;
      s
    in
    let squeeze () =
      let underlying =
        Challenge.Constant.of_bits
          (squeeze sponge ~length:Challenge.Constant.length)
      in
      Scalar_challenge.create underlying
    in
    (absorb sponge, squeeze)
  in
  let old_bulletproof_challenges =
    Vector.map ~f:Ipa.Step.compute_challenges old_bulletproof_challenges
  in
  (let challenges_digest =
     let open Tick_field_sponge.Field in
     let sponge = create Tick_field_sponge.params in
     Vector.iter old_bulletproof_challenges ~f:(Vector.iter ~f:(absorb sponge)) ;
     squeeze sponge
   in
   absorb challenges_digest ;
   absorb evals.ft_eval1 ;
   let xs = Plonk_types.Evals.to_absorption_sequence evals.evals.evals in
   let x1, x2 = evals.evals.public_input in
   Array.iter ~f:absorb x1 ;
   Array.iter ~f:absorb x2 ;
   List.iter xs ~f:(fun (x1, x2) ->
       Array.iter ~f:absorb x1 ; Array.iter ~f:absorb x2 ) ) ;
  let xi_chal = squeeze () in
  let xi = sc xi_chal in
  let r_chal = squeeze () in
  let r = sc r_chal in
  Timer.clock __LOC__ ;
  (* TODO: The deferred values "bulletproof_challenges" should get routed
     into a "batch dlog Tick acc verifier" *)
  let actual_proofs_verified = Vector.length old_bulletproof_challenges in
  Timer.clock __LOC__ ;
  let combined_inner_product_actual =
    Wrap.combined_inner_product ~env:tick_env ~plonk:tick_plonk_minimal
      ~domain:tick_domain ~ft_eval1:evals.ft_eval1
      ~actual_proofs_verified:(Nat.Add.create actual_proofs_verified)
      evals.evals ~old_bulletproof_challenges ~r ~xi ~zeta ~zetaw
  in
  Timer.clock __LOC__ ;
  let bulletproof_challenges =
    Ipa.Step.compute_challenges bulletproof_challenges
  in
  Timer.clock __LOC__ ;
  let b_actual =
    let challenge_poly =
      unstage
        (Wrap.challenge_polynomial (Vector.to_array bulletproof_challenges))
    in
    Tick.Field.(challenge_poly zeta + (r * challenge_poly zetaw))
  in
  let to_shifted =
    Shifted_value.Type1.of_field (module Tick.Field) ~shift:Shifts.tick1
  in
  { xi = xi_chal
  ; plonk
  ; combined_inner_product = to_shifted combined_inner_product_actual
  ; branch_data
  ; bulletproof_challenges
  ; b = to_shifted b_actual
  }
