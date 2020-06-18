(* q > p *)
open Core_kernel
open Import
open Util
open Types.Pairing_based
module SC = Scalar_challenge
open Pickles_types
open Common
open Import

module Make
    (Inputs : Intf.Pairing_main_inputs.S
              with type Impl.field = Backend.Tick.Field.t
               and type G.Constant.Scalar.t = Backend.Tock.Field.t) =
struct
  open Inputs
  open Impl
  module PC = G
  module Fp = Impl.Field
  module Challenge = Challenge.Make (Impl)
  module Digest = Digest.Make (Impl)

  (* q > p *)
  module Fq = struct
    let size_in_bits = Fp.size_in_bits

    module Constant = Fq

    type t = (* Low bits, high bit *)
      Fp.t * Boolean.var

    let typ =
      Typ.transport
        (Typ.tuple2 Fp.typ Boolean.typ)
        ~there:(fun x ->
          let low, high = Util.split_last (Fq.to_bits x) in
          (Fp.Constant.project low, high) )
        ~back:(fun (low, high) ->
          let low, _ = Util.split_last (Fp.Constant.unpack low) in
          Fq.of_bits (low @ [high]) )

    let to_bits (x, b) = Field.unpack x ~length:(Field.size_in_bits - 1) @ [b]
  end

  let debug = false

  let print_g lab g =
    if debug then
      as_prover
        As_prover.(
          fun () ->
            match G.to_field_elements g with
            | [x; y] ->
                printf !"%s: %!" lab ;
                Field.Constant.print (read_var x) ;
                printf ", %!" ;
                Field.Constant.print (read_var y) ;
                printf "\n%!"
            | _ ->
                assert false)

  let print_chal lab chal =
    if debug then
      as_prover
        As_prover.(
          fun () ->
            printf
              !"%s: %{sexp:Challenge.Constant.t}\n%!"
              lab (read Challenge.typ chal))

  let print_fp lab x =
    if debug then
      as_prover (fun () ->
          printf "%s: %!" lab ;
          Fp.Constant.print (As_prover.read Field.typ x) ;
          printf "\n%!" )

  let print_bool lab x =
    if debug then
      as_prover (fun () ->
          printf "%s: %b\n%!" lab (As_prover.read Boolean.typ x) )

  let equal_g g1 g2 =
    List.map2_exn ~f:Field.equal (G.to_field_elements g1)
      (G.to_field_elements g2)
    |> Boolean.all

  let rec absorb : type a.
      Sponge.t -> (a, < scalar: Fq.t ; g1: G.t >) Type.t -> a -> unit =
   fun sponge ty t ->
    match ty with
    | PC ->
        List.iter (G.to_field_elements t) ~f:(fun x ->
            Sponge.absorb sponge (`Field x) )
    | Scalar ->
        let low_bits, high_bit = t in
        Sponge.absorb sponge (`Field low_bits) ;
        Sponge.absorb sponge (`Bits [high_bit])
    | Without_degree_bound ->
        Array.iter t ~f:(fun t -> absorb sponge PC t)
    | With_degree_bound ->
        Array.iter t.unshifted ~f:(fun t -> absorb sponge PC t) ;
        absorb sponge PC t.shifted
    | ty1 :: ty2 ->
        let t1, t2 = t in
        let absorb t = absorb sponge t in
        absorb ty1 t1 ; absorb ty2 t2

  module Scalar_challenge = SC.Make (Impl) (G) (Challenge) (Endo.Dlog)

  let squeeze_scalar sponge : Scalar_challenge.t =
    Scalar_challenge (Sponge.squeeze sponge ~length:Challenge.length)

  let bullet_reduce sponge gammas =
    let absorb t = absorb sponge t in
    let prechallenges =
      Array.mapi gammas ~f:(fun i gammas_i ->
          absorb (PC :: PC) gammas_i ;
          squeeze_scalar sponge )
    in
    let term_and_challenge (l, r) pre =
      let pre_is_square =
        exists Boolean.typ
          ~compute:
            As_prover.(
              fun () ->
                Fq.Constant.(
                  is_square
                    (Scalar_challenge.Constant.to_field
                       (read Scalar_challenge.typ pre))))
      in
      let left_term =
        let base =
          G.if_ pre_is_square ~then_:l
            ~else_:(G.scale_by_quadratic_nonresidue l)
        in
        Scalar_challenge.endo base pre
      in
      let right_term =
        let base =
          G.if_ pre_is_square ~then_:r
            ~else_:(G.scale_by_quadratic_nonresidue_inv r)
        in
        Scalar_challenge.endo_inv base pre
      in
      ( G.(left_term + right_term)
      , {Bulletproof_challenge.prechallenge= pre; is_square= pre_is_square} )
    in
    let terms, challenges =
      Array.map2_exn gammas prechallenges ~f:term_and_challenge |> Array.unzip
    in
    (Array.reduce_exn terms ~f:G.( + ), challenges)

  let h_precomp = Lazy.map ~f:G.Scaling_precomputation.create Generators.h

  let group_map =
    let f =
      lazy
        (let module M =
           Group_map.Bw19.Make (Field.Constant) (Field)
             (struct
               let params =
                 Group_map.Bw19.Params.create
                   (module Field.Constant)
                   {b= G.Params.b}
             end)
         in
        let open M in
        Snarky_group_map.Checked.wrap
          (module Impl)
          ~potential_xs
          ~y_squared:(fun ~x ->
            Field.(
              (x * x * x) + (constant G.Params.a * x) + constant G.Params.b) )
        |> unstage)
    in
    fun x -> Lazy.force f x

  let check_bulletproof ~pcs_batch ~domain_h ~domain_k ~sponge ~xi
      ~combined_inner_product
      ~
      (* Corresponds to y in figure 7 of WTS *)
      (* sum_i r^i sum_j xi^j f_j(beta_i) *)
      (advice : _ Openings.Bulletproof.Advice.t)
      ~polynomials:(without_degree_bound, with_degree_bound)
      ~openings_proof:({lr; delta; z_1; z_2; sg} :
                        (G.t, Fq.t) Openings.Bulletproof.t) =
    with_label __LOC__ (fun () ->
        (* a_hat should be equal to
       sum_i < t, r^i pows(beta_i) >
       = sum_i r^i < t, pows(beta_i) > *)
        let u =
          let t = Sponge.squeeze_field sponge in
          group_map t
        in
        let open G in
        let combined_polynomial (* Corresponds to xi in figure 7 of WTS *) =
          Pcs_batch.combine_split_commitments pcs_batch
            ~scale:Scalar_challenge.endo ~add:( + ) ~xi without_degree_bound
            with_degree_bound
        in
        let lr_prod, challenges = bullet_reduce sponge lr in
        let p_prime =
          combined_polynomial + scale u (Fq.to_bits combined_inner_product)
        in
        let q = p_prime + lr_prod in
        absorb sponge PC delta ;
        let c = squeeze_scalar sponge in
        (* c Q + delta = z1 (G + b U) + z2 H *)
        let lhs =
          let cq = Scalar_challenge.endo q c in
          cq + delta
        in
        let rhs =
          let scale t x = scale t (Fq.to_bits x) in
          let b_u = scale u advice.b in
          let z_1_g_plus_b_u = scale (sg + b_u) z_1 in
          let z2_h =
            G.multiscale_known [|(Fq.to_bits z_2, Lazy.force h_precomp)|]
          in
          z_1_g_plus_b_u + z2_h
        in
        (`Success (equal_g lhs rhs), challenges) )

  let lagrange_precomputations =
    lazy
      (Array.map
         (Lazy.force Input_domain.lagrange_commitments)
         ~f:G.Scaling_precomputation.create)

  let incrementally_verify_proof (type b)
      (module Branching : Nat.Add.Intf with type n = b) ~domain_h ~domain_k
      ~verification_key:(m : _ Abc.t Matrix_evals.t) ~xi ~sponge ~public_input
      ~(sg_old : (_, Branching.n) Vector.t) ~combined_inner_product ~advice
      ~(messages : _ Dlog_marlin_types.Messages.t) ~openings_proof =
    with_label __LOC__ (fun () ->
        let receive ty f =
          with_label __LOC__ (fun () ->
              let x = f messages in
              absorb sponge ty x ; x )
        in
        let sample () = Sponge.squeeze sponge ~length:Challenge.length in
        let sample_scalar () = squeeze_scalar sponge in
        let open Dlog_marlin_types.Messages in
        let x_hat =
          assert (
            Int.ceil_pow2 (Array.length public_input)
            = Domain.size Input_domain.domain ) ;
          G.multiscale_known
            (Array.mapi public_input ~f:(fun i x ->
                 (x, (Lazy.force lagrange_precomputations).(i)) ))
        in
        let without = Type.Without_degree_bound in
        let with_ = Type.With_degree_bound in
        absorb sponge PC x_hat ;
        let w_hat = receive without w_hat in
        let z_hat_a = receive without z_hat_a in
        let z_hat_b = receive without z_hat_b in
        let alpha = sample () in
        let eta_a = sample () in
        let eta_b = sample () in
        let eta_c = sample () in
        let g_1, h_1 = receive (with_ :: without) gh_1 in
        let beta_1 = sample_scalar () in
        (* At this point, we should use the previous "bulletproof_challenges" to
       compute to compute f(beta_1) outside the snark
       where f is the polynomial corresponding to sg_old
    *)
        let sigma_2, (g_2, h_2) =
          receive (Scalar :: with_ :: without) sigma_gh_2
        in
        let beta_2 = sample_scalar () in
        let sigma_3, (g_3, h_3) =
          receive (Scalar :: with_ :: without) sigma_gh_3
        in
        let beta_3 = sample_scalar () in
        let sponge_before_evaluations = Sponge.copy sponge in
        let sponge_digest_before_evaluations =
          Sponge.squeeze sponge ~length:Digest.length
        in
        (* xi, r are sampled here using the other sponge. *)
        (* No need to expose the polynomial evaluations as deferred values as they're
       not needed here for the incremental verification. All we need is a_hat and
       "combined_inner_product".

       Then, in the other proof, we can witness the evaluations and check their correctness
       against "combined_inner_product" *)
        let bulletproof_challenges =
          (* This sponge needs to be initialized with (some derivative of)
         1. The polynomial commitments
         2. The combined inner product
         3. The challenge points.

         It should be sufficient to fork the sponge after squeezing beta_3 and then to absorb
         the combined inner product. 
      *)
          let without_degree_bound =
            let T = Branching.eq in
            Vector.append
              (Vector.map sg_old ~f:(fun g -> [|g|]))
              [ [|x_hat|]
              ; w_hat
              ; z_hat_a
              ; z_hat_b
              ; h_1
              ; h_2
              ; h_3
              ; m.row.a
              ; m.row.b
              ; m.row.c
              ; m.col.a
              ; m.col.b
              ; m.col.c
              ; m.value.a
              ; m.value.b
              ; m.value.c
              ; m.rc.a
              ; m.rc.b
              ; m.rc.c ]
              (snd (Branching.add Nat.N19.n))
          in
          check_bulletproof
            ~pcs_batch:
              (Common.dlog_pcs_batch
                 ~h_minus_1:(Domain.size domain_h - 1)
                 ~k_minus_1:(Domain.size domain_k - 1)
                 (Branching.add Nat.N19.n))
            ~domain_h ~domain_k ~sponge:sponge_before_evaluations ~xi
            ~combined_inner_product ~advice ~openings_proof
            ~polynomials:(without_degree_bound, [g_1; g_2; g_3])
        in
        ( sponge_digest_before_evaluations
        , bulletproof_challenges
        , { Proof_state.Deferred_values.Marlin.sigma_2
          ; sigma_3
          ; alpha
          ; eta_a
          ; eta_b
          ; eta_c
          ; beta_1
          ; beta_2
          ; beta_3 } ) )

  let pack_scalar_challenge (Pickles_types.Scalar_challenge.Scalar_challenge t)
      =
    Field.pack (Challenge.to_bits t)

  let finalize_other_proof ~input_domain ~domain_k ~domain_h ~sponge
      ({xi; r; r_xi_sum; marlin} :
        _ Types.Dlog_based.Proof_state.Deferred_values.t) (evals, x_hat_beta_1)
      =
    let open Vector in
    let open Pairing_marlin_types in
    let absorb_field x = Sponge.absorb sponge (`Field x) in
    absorb_field x_hat_beta_1 ;
    Vector.iter (Evals.to_vector evals) ~f:absorb_field ;
    let open Fp in
    let xi_actual = squeeze_scalar sponge in
    let r_actual = squeeze_scalar sponge in
    let xi_correct =
      Fp.equal (pack_scalar_challenge xi_actual) (pack_scalar_challenge xi)
    in
    let r_correct =
      Fp.equal (pack_scalar_challenge r_actual) (pack_scalar_challenge r)
    in
    let scalar = SC.to_field_checked (module Impl) ~endo:Endo.Pairing.scalar in
    let r = scalar r in
    let xi = scalar xi in
    let combined_evaluation batch pt without_bound =
      Pcs_batch.combine_evaluations batch ~crs_max_degree ~mul ~add ~one
        ~evaluation_point:pt ~xi without_bound []
    in
    let marlin =
      Types.Pairing_based.Proof_state.Deferred_values.Marlin.map_challenges
        ~f:Field.pack ~scalar marlin
    in
    let beta1, beta2, beta3 =
      Evals.to_combined_vectors ~x_hat:x_hat_beta_1 evals
    in
    let r_xi_sum_correct =
      let r_xi_sum_actual =
        r
        * ( combined_evaluation Common.Pairing_pcs_batch.beta_1 marlin.beta_1
              beta1
          + r
            * ( combined_evaluation Common.Pairing_pcs_batch.beta_2
                  marlin.beta_2 beta2
              + r
                * combined_evaluation Common.Pairing_pcs_batch.beta_3
                    marlin.beta_3 beta3 ) )
      in
      Fp.equal r_xi_sum r_xi_sum_actual
    in
    let marlin_checks =
      Marlin_checks.checked
        (module Impl)
        ~x_hat_beta_1 ~input_domain ~domain_h ~domain_k marlin evals
    in
    List.iter
      ~f:(Tuple2.uncurry (Fn.flip print_bool))
      [ (xi_correct, "xi_correct")
      ; (r_correct, "r_correct")
      ; (r_xi_sum_correct, "r_xi_sum_correct")
      ; (marlin_checks, "marlin_checks") ] ;
    Boolean.all [xi_correct; r_correct; r_xi_sum_correct; marlin_checks]

  let hash_me_only (type s) ~index
      (state_to_field_elements : s -> Field.t array) =
    let open Types.Pairing_based.Proof_state.Me_only in
    let after_index =
      let sponge = Sponge.create sponge_params in
      Array.iter
        (Types.index_to_field_elements
           ~g:
             (fun (z :
                    Inputs.G.t
                    Dlog_marlin_types.Poly_comm.Without_degree_bound.t) ->
             List.init
               (Array.length z * 2)
               (fun i ->
                 let xy = G.to_field_elements z.(i / 2) in
                 if i mod 2 = 0 then List.nth_exn xy 0 else List.nth_exn xy 1
                 ) )
           index)
        ~f:(fun x -> Sponge.absorb sponge (`Field x)) ;
      sponge
    in
    stage (fun t ->
        let sponge = Sponge.copy after_index in
        Array.iter
          ~f:(fun x -> Sponge.absorb sponge (`Field x))
          (to_field_elements_without_index t ~app_state:state_to_field_elements
             ~g:G.to_field_elements) ;
        Sponge.squeeze sponge ~length:Digest.length )

  let pack_scalar_challenge (Scalar_challenge c : Scalar_challenge.t) =
    Field.pack (Challenge.to_bits c)

  (* TODO *)
  let assert_eq_marlin
      (m1 :
        ( 'a
        , Inputs.Impl.Field.t Pickles_types.Scalar_challenge.t
        , Inputs.Impl.Field.t * Inputs.Impl.Boolean.var )
        Types.Pairing_based.Proof_state.Deferred_values.Marlin.t)
      (m2 :
        ( Inputs.Impl.Boolean.var list
        , Scalar_challenge.t
        , Fq.t )
        Types.Pairing_based.Proof_state.Deferred_values.Marlin.t) =
    let open Types.Dlog_based.Proof_state.Deferred_values.Marlin in
    let fq (x1, b1) (x2, b2) =
      Field.Assert.equal x1 x2 ;
      Boolean.Assert.(b1 = b2)
    in
    let chal c1 c2 = Field.Assert.equal c1 (Field.project c2) in
    let scalar_chal (Scalar_challenge t1 : _ Pickles_types.Scalar_challenge.t)
        (Scalar_challenge t2 : Scalar_challenge.t) =
      Field.Assert.equal t1 (Field.project t2)
    in
    chal m1.alpha m2.alpha ;
    chal m1.eta_a m2.eta_a ;
    chal m1.eta_b m2.eta_b ;
    chal m1.eta_c m2.eta_c ;
    scalar_chal m1.beta_1 m2.beta_1 ;
    fq m1.sigma_2 m2.sigma_2 ;
    scalar_chal m1.beta_2 m2.beta_2 ;
    fq m1.sigma_3 m2.sigma_3 ;
    scalar_chal m1.beta_3 m2.beta_3

  let verify ~branching ~is_base_case ~sg_old
      ~(opening : _ Pickles_types.Dlog_marlin_types.Openings.Bulletproof.t)
      ~messages ~wrap_domains:(domain_h, domain_k) ~wrap_verification_key
      statement (unfinalized : _ Types.Pairing_based.Proof_state.Per_proof.t) =
    let public_input =
      let fp x =
        [|Bitstring_lib.Bitstring.Lsb_first.to_list (Fp.unpack_full x)|]
      in
      Array.append
        [|[Boolean.true_]|]
        (Spec.pack
           (module Impl)
           fp Types.Dlog_based.Statement.spec
           (Types.Dlog_based.Statement.to_data statement))
    in
    let sponge = Sponge.create sponge_params in
    let { Types.Pairing_based.Proof_state.Deferred_values.xi
        ; combined_inner_product
        ; b } =
      unfinalized.deferred_values
    in
    let ( sponge_digest_before_evaluations_actual
        , (`Success bulletproof_success, bulletproof_challenges_actual)
        , marlin_actual ) =
      let xi =
        Pickles_types.Scalar_challenge.map xi
          ~f:(Field.unpack ~length:Challenge.length)
      in
      incrementally_verify_proof branching ~domain_h ~domain_k ~xi
        ~verification_key:wrap_verification_key ~sponge ~public_input ~sg_old
        ~combined_inner_product ~advice:{b} ~messages ~openings_proof:opening
    in
    assert_eq_marlin unfinalized.deferred_values.marlin marlin_actual ;
    with_label __LOC__ (fun () ->
        Field.Assert.equal unfinalized.sponge_digest_before_evaluations
          (Fp.pack sponge_digest_before_evaluations_actual) ;
        Array.iteri
          (Vector.to_array unfinalized.deferred_values.bulletproof_challenges)
          ~f:(fun i c1 ->
            let c2 = bulletproof_challenges_actual.(i) in
            Boolean.Assert.( = ) c1.Bulletproof_challenge.is_square
              (Boolean.if_ is_base_case ~then_:c1.is_square ~else_:c2.is_square) ;
            let (Pickles_types.Scalar_challenge.Scalar_challenge c1) =
              c1.prechallenge
            in
            let c2 =
              Field.if_ is_base_case ~then_:c1
                ~else_:(pack_scalar_challenge c2.prechallenge)
            in
            Field.Assert.equal c1 c2 ) ) ;
    bulletproof_success
end

include Make (Pairing_main_inputs)
