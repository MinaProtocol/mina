(* q > p *)
module D = Digest
open Core_kernel
open Import
open Util
open Types.Pairing_based
open Pickles_types

module Main (Inputs : Intf.Pairing_main_inputs.S) = struct
  open Inputs
  open Impl
  module PC = G
  module Fp = Impl.Field
  module Challenge = Challenge.Make (Impl)
  module Digest = D.Make (Impl)

  (* q > p *)
  module Fq = struct
    let size_in_bits = Fp.size_in_bits

    module Constant = struct
      type t = Fp.Constant.t * bool
    end

    type t = (* Low bits, high bit *)
      Fp.t * Boolean.var

    let typ = Typ.tuple2 Fp.typ Boolean.typ

    let to_bits (x, b) = Field.unpack x ~length:(Field.size_in_bits - 1) @ [b]
  end

  module Requests = struct
    open Snarky.Request
    open Types
    open Pairing_marlin_types

    module Compute = struct
      type _ t += Fq_is_square : bool list -> bool t
    end

    type _ t +=
      | Prev_evals : Field.Constant.t Evals.t t
      | Prev_messages : (PC.Constant.t, Fq.Constant.t) Messages.t t
      | Prev_openings_proof :
          (Fq.Constant.t, G.Constant.t) Pairing_based.Openings.Bulletproof.t t
      | Prev_app_state : App_state.Constant.t t
      | Prev_sg : G.Constant.t t
      | Me_only :
          ( G.Constant.t
          , App_state.Constant.t )
          Pairing_based.Proof_state.Me_only.t
          t
      | Prev_proof_state :
          ( Challenge.Constant.t
          , Fp.Constant.t
          , Challenge.Constant.t
          , Fq.Constant.t
          , Digest.Unpacked.Constant.t
          , Digest.Unpacked.Constant.t )
          Dlog_based.Proof_state.t
          t
  end

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
    | ty1 :: ty2 ->
        let absorb t = absorb sponge t in
        let t1, t2 = t in
        absorb ty1 t1 ; absorb ty2 t2

  let bullet_reduce sponge gammas =
    let absorb t = absorb sponge t in
    let prechallenges =
      Array.map gammas ~f:(fun gammas_i ->
          absorb (PC :: PC) gammas_i ;
          Sponge.squeeze sponge ~length:Challenge.length )
    in
    let term_and_challenge (gamma_neg_one, gamma_one) pre =
      let pre_is_square =
        exists Boolean.typ
          ~request:
            As_prover.(
              fun () ->
                Requests.Compute.Fq_is_square
                  (List.map pre ~f:(read Boolean.typ)))
      in
      let left_term =
        let base =
          G.if_ pre_is_square ~then_:gamma_neg_one
            ~else_:(G.scale_by_quadratic_nonresidue gamma_neg_one)
        in
        G.scale base pre
      in
      let right_term =
        let base =
          G.if_ pre_is_square ~then_:gamma_one
            ~else_:(G.scale_by_quadratic_nonresidue_inv gamma_one)
        in
        G.scale_inv base pre
      in
      ( G.(left_term + right_term)
      , {Bulletproof_challenge.prechallenge= pre; is_square= pre_is_square} )
    in
    let terms, challenges =
      Array.map2_exn gammas prechallenges ~f:term_and_challenge |> Array.unzip
    in
    (Array.reduce_exn terms ~f:G.( + ), challenges)

  let assert_equal_g g1 g2 =
    List.iter2_exn ~f:Field.Assert.equal (G.to_field_elements g1)
      (G.to_field_elements g2)

  let equal_g g1 g2 =
    List.map2_exn ~f:Field.equal (G.to_field_elements g1)
      (G.to_field_elements g2)
    |> Boolean.all

  let dlog_pcs_batch = Common.dlog_pcs_batch ~domain_h ~domain_k

  (* Confused about how verifier chooses c in 3. Looks like prover can use
    whatever c they like *)
  let check_bulletproof ~g ~h ~sponge ~xi ~sg_old ~combined_inner_product
      ~
      (* Corresponds to y in figure 7 of WTS *)
      (* sum_i r^i sum_j xi^j f_j(beta_i) *)
      (advice : _ Openings.Bulletproof.Advice.t)
      ~polynomials:(without_degree_bound, with_degree_bound)
      ~(openings_proof : (Fq.t, G.t) Openings.Bulletproof.t) =
    (* a_hat should be equal to
       sum_i < t, r^i pows(beta_i) >
       = sum_i r^i < t, pows(beta_i) > *)
    let () =
      (* Absorb the statement ( combined_polynomial, combined_inner_product, combined_evaluation ) *)
      ()
    in
    let proof = openings_proof in
    (* TODO: Absorb (combined_polynomial, inner_product_result/tau *)
    let open G in
    let combined_polynomial (* Corresponds to xi in figure 7 of WTS *) =
      Pcs_batch.combine_commitments dlog_pcs_batch ~scale ~add:( + ) ~xi
        (sg_old :: without_degree_bound)
        with_degree_bound
    in
    (* TODO: Absorb challenges into the sponge and expose it as another input *)
    let gamma_prod, challenges = bullet_reduce sponge proof.gammas in
    let gamma0 =
      let tau = scale g (Fq.to_bits combined_inner_product) in
      combined_polynomial + tau
    in
    let a_hat = Fq.to_bits advice.a_hat in
    let lhs = scale (gamma0 + gamma_prod + proof.beta) a_hat + proof.delta in
    let rhs =
      scale (advice.sg + scale g a_hat) (Fq.to_bits proof.z_1)
      + scale h (Fq.to_bits proof.z_2)
    in
    (`Success (equal_g lhs rhs), challenges)

  let lagrange_precomputations =
    Array.map Input_domain.lagrange_commitments
      ~f:G.Scaling_precomputation.create

  (* How to advance the proof state in "dlog main"

   exists g_old challenges_old.
   Sample a challenge point for g_old. Compute b_challenges_old(g_old).
   Then compute the combined_inner_product using this. *)
  let incrementally_verify_proof ~verification_key:(m : _ Abc.t Matrix_evals.t)
      ~xi ~sponge ~public_input ~sg_old ~combined_inner_product ~advice
      ~messages ~openings_proof =
    let receive ty f =
      let x = f messages in
      absorb sponge ty x ; x
    in
    let sample () = Sponge.squeeze sponge ~length:Challenge.length in
    let open Pairing_marlin_types.Messages in
    (* Compute the lagrange interpolation of the input by ourself.
        Add it to the opening.

        These scalings are only 2 constraints per bit.
        Could be worse!
    *)
    let x_hat =
      (* Must handle 1 ! *)
      G.multiscale_known
        (Array.mapi public_input ~f:(fun i x ->
             (x, lagrange_precomputations.(i)) ))
    in
    (* No need to absorb the public input into the sponge as we've already
      absorbed x'_hat, a0, and y0 *)
    let w_hat = receive PC w_hat in
    let s = receive PC s in
    let z_hat_a = receive PC z_hat_a in
    let z_hat_b = receive PC z_hat_b in
    let alpha = sample () in
    let eta_a = sample () in
    let eta_b = sample () in
    let eta_c = sample () in
    let g_1, h_1 = receive (Type.degree_bounded_pc :: PC) gh_1 in
    let beta_1 = sample () in
    (* At this point, we should use the previous "bulletproof_challenges" to
       compute to compute f(beta_1) outside the snark
       where f is the polynomial corresponding to sg_old
    *)
    let sigma_2, (g_2, h_2) =
      receive (Scalar :: Type.degree_bounded_pc :: PC) sigma_gh_2
    in
    let beta_2 = sample () in
    let sigma_3, (g_3, h_3) =
      receive (Scalar :: Type.degree_bounded_pc :: PC) sigma_gh_3
    in
    let beta_3 = sample () in
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
      (* TODO: Absorb xi and combined_inner_product ? *)
      check_bulletproof ~g:Generators.g ~h:Generators.h ~sponge ~xi ~sg_old
        ~combined_inner_product ~advice ~openings_proof
        ~polynomials:
          ( [ x_hat
            ; w_hat
            ; s
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
            ; m.value.c ]
          , [g_1; g_2; g_3] )
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
      ; beta_3 } )

  let marlin_data
      { Proof_state.Deferred_values.Marlin.sigma_2
      ; sigma_3
      ; alpha
      ; eta_a
      ; eta_b
      ; eta_c
      ; beta_1
      ; beta_2
      ; beta_3 } =
    let fq_data ((x, b) : Fq.t) = ([x], [b]) in
    Data.concat
      ( fq_data sigma_2 :: fq_data sigma_3
      :: List.map ~f:Data.bits
           [alpha; eta_a; eta_b; eta_c; beta_1; beta_2; beta_3] )

  let chals_data chals =
    Array.map chals ~f:(fun {Bulletproof_challenge.prechallenge; is_square} ->
        Data.bits (is_square :: prechallenge) )
    |> Array.reduce_exn ~f:Data.append

  (* The problem is having inputs which are used non opaquely.
     Maybe we can do that with the x_hat evaluation?
  *)

  let combined_evaluation ~xi Vector.(eval0 :: evals) =
    List.fold_left (Vector.to_list evals) ~init:eval0 ~f:(fun acc eval ->
        Fp.((xi * acc) + eval) )

  module Marlin_checks = Marlin_checks.Make (Impl)

  let finalize_other_proof ~domain_k ~domain_h ~sponge
      ({xi; r; r_xi_sum; marlin} :
        _ Types.Dlog_based.Proof_state.Deferred_values.t) =
    let open Vector in
    (*
    let sponge =
      let s = Sponge.create sponge_params in
      Sponge.absorb s (`Bits digest_before_evaluations) ;
      s
    in *)
    let beta_1_evals, beta_2_evals, beta_3_evals =
      exists (Pairing_marlin_types.Evals.typ Field.typ) ~request:(fun () ->
          Requests.Prev_evals )
    in
    let absorb_field x = Sponge.absorb sponge (`Field x) in
    Vector.iter beta_1_evals ~f:absorb_field ;
    Vector.iter beta_2_evals ~f:absorb_field ;
    Vector.iter beta_3_evals ~f:absorb_field ;
    let open Fp in
    let xi_actual = Sponge.squeeze sponge ~length:Challenge.length in
    let r_actual = Sponge.squeeze sponge ~length:Challenge.length in
    Boolean.all
      [ Fp.equal (Field.pack xi_actual) xi
      ; Fp.equal (Field.pack r_actual) r
      ; (let r_xi_sum_actual =
           r
           * ( combined_evaluation ~xi beta_1_evals
             + r
               * ( combined_evaluation ~xi beta_2_evals
                 + (r * combined_evaluation ~xi beta_3_evals) ) )
         in
         Fp.equal r_xi_sum r_xi_sum_actual)
      ; Marlin_checks.check ~input_domain:Input_domain.domain ~domain_h
          ~domain_k marlin beta_1_evals beta_2_evals beta_3_evals ]

  let hash_me_only t =
    let elts =
      Types.Pairing_based.Proof_state.Me_only.to_field_elements t
        ~app_state:App_state.to_field_elements ~g:G.to_field_elements
    in
    let sponge = Sponge.create sponge_params in
    Array.iter elts ~f:(fun x -> Sponge.absorb sponge (`Field x)) ;
    Sponge.squeeze sponge ~length:Digest.length

  let decompress_me_only digest =
    let (me_only : _ Types.Pairing_based.Proof_state.Me_only.t) =
      exists (Types.Pairing_based.Proof_state.Me_only.typ G.typ App_state.typ)
        ~request:(fun () -> Requests.Me_only)
    in
    Field.Assert.equal digest (Field.pack (hash_me_only me_only)) ;
    me_only

  let pack_data (fp, fq, challenge, fq_challenge, digest) =
    Array.concat
      [ Array.of_list_map (Vector.to_list fp) ~f:(fun x ->
            Bitstring_lib.Bitstring.Lsb_first.to_list (Fp.unpack_full x) )
      ; Array.of_list_map (Vector.to_list fq) ~f:(fun (low_bits, high_bit) ->
            let low_bits = Fp.unpack ~length:(Fq.size_in_bits - 1) low_bits in
            low_bits @ [high_bit] )
      ; Vector.to_array challenge
      ; Vector.to_array fq_challenge
      ; Vector.to_array digest ]

  let main
      ({ proof_state=
           { deferred_values=
               { marlin
               ; combined_inner_product
               ; xi
               ; bulletproof_challenges
               ; a_hat }
           ; sponge_digest_before_evaluations
           ; was_base_case
           ; me_only= me_only_digest }
       ; pass_through } :
        _ Statement.t) =
    let { Types.Pairing_based.Proof_state.Me_only.app_state
        ; dlog_marlin_index
        ; sg } =
      decompress_me_only me_only_digest
    in
    let ( prev_deferred_values
        , prev_sponge_digest_before_evaluations
        , prev_proof_state ) =
      let state =
        exists
          (Types.Dlog_based.Proof_state.typ Challenge.typ Fp.typ Fq.typ
             Digest.Unpacked.typ Digest.Unpacked.typ) ~request:(fun () ->
            Requests.Prev_proof_state )
      in
      ( Types.Dlog_based.Proof_state.Deferred_values.map_challenges ~f:Fp.pack
          state.deferred_values
      , Fp.pack state.sponge_digest_before_evaluations
      , state )
    in
    let prev_app_state =
      exists App_state.typ ~request:(fun () -> Requests.Prev_app_state)
    in
    let sg_old = exists G.typ ~request:(fun () -> Requests.Prev_sg) in
    let prev_statement =
      (* TODO: A lot of repeated hashing happening here on the dlog_marlin_index *)
      let prev_me_only =
        hash_me_only {app_state= prev_app_state; dlog_marlin_index; sg= sg_old}
      in
      { Types.Dlog_based.Statement.pass_through= prev_me_only
      ; proof_state= prev_proof_state }
    in
    let sponge =
      let s = Sponge.create sponge_params in
      Sponge.absorb s (`Field prev_sponge_digest_before_evaluations) ;
      s
    in
    let prev_proof_finalized =
      finalize_other_proof ~domain_k ~domain_h ~sponge prev_deferred_values
    in
    let sponge =
      let s = Sponge.create sponge_params in
      Array.iter (App_state.to_field_elements app_state) ~f:(fun x ->
          Sponge.absorb s (`Field x) ) ;
      s
    in
    let ( sponge_digest_before_evaluations_actual
        , (`Success bullet_proof_success, bulletproof_challenges_actual)
        , marlin_actual ) =
      let messages =
        exists (Pairing_marlin_types.Messages.typ PC.typ Fq.typ)
          ~request:(fun () -> Requests.Prev_messages)
      in
      let openings_proof =
        exists
          (Types.Pairing_based.Openings.Bulletproof.typ Fq.typ G.typ
             ~length:(Array.length bulletproof_challenges))
          ~request:(fun () -> Requests.Prev_openings_proof)
      in
      incrementally_verify_proof ~xi ~verification_key:dlog_marlin_index
        ~sponge
        ~public_input:
          (pack_data (Types.Dlog_based.Statement.to_data prev_statement))
        ~sg_old ~combined_inner_product ~advice:{a_hat; sg} ~messages
        ~openings_proof
    in
    let is_base_case = App_state.is_base_case app_state in
    Boolean.Assert.(is_base_case = was_base_case) ;
    let prev_proof_correct =
      Boolean.all [bullet_proof_success; prev_proof_finalized]
    in
    (*
    Data.(
      assert_equal (fun public_input computed ->
          (* To make our lives a bit easier in the base case. *)
          Field.Assert.equal
            public_input
            (Field.if_ is_base_case
               ~then_:public_input
               ~else_:computed) )
        ~pack:Field.pack
        ~field_size:Field.size_in_bits
        (chals_data bulletproof_challenges @ marlin_data marlin)
        (chals_data bulletproof_challenges_actual @ marlin_data marlin_actual)) ; *)
    Boolean.(
      Assert.any
        [ prev_proof_correct && App_state.check_update prev_app_state app_state
        ; is_base_case ])

  (* TODO: Turn this on -- think about what to do in the base case.
     Also need to expose base_case_ness for the next proof. 
    ;
    Field.Assert.equal sponge_digest_before_evaluations
      (Field.pack sponge_digest_before_evaluations_actual) ;
         *)

  (* TODO: The code here and in [pack_data] in dlog_main should be unified into
   one piece of code from which both functions are derived. *)
  let main
      ( bool
      , fq
      , (digest : (Fp.t, _) Vector.t)
      , (challenge : (Fp.t, _) Vector.t)
      , (bulletproof_challenges : Fp.t array) ) =
    let unpack length = Vector.map ~f:(Fp.unpack ~length) in
    ( bool
    , fq
    , digest
    , unpack Challenge.length challenge
    , Array.map bulletproof_challenges ~f:(fun t ->
          Types.Pairing_based.Bulletproof_challenge.unpack
            (Fp.unpack ~length:(1 + Challenge.length) t) ) )
    |> Types.Pairing_based.Statement.of_data |> main
end

(* Evaluations:

       | g_1 | h_1 | z_A | z_B | w   | s   | g_2 | h_2 | g_3 | h_3 | indexpolys
beta_1 |  *  |  *  |  *  |  *  |  *  |  *  |     |     |     |     |
beta_2 |     |     |     |     |     |     |  *  |  *  |     |     |
beta_3 |     |     |     |     |     |     |     |     |  *  |  *  |  *

* = proof element in vanilla marlin
*)

(* The ideal thing to do would be to sample

   two 382 / 2 bit numbers c, d such that

   (1) c * d = 1
   (2) c is a square (this implies d is a square)

   note that (1) implies int(c) * int(d) > p, so
   the combined bit size of c, d is at least 382 bits.

   d * c + e * p = 1

   C * D = 1 + k * p
*)

(* TODO: Compute the number of pieces that we should chop

   the h_3 polynomial up into. At a certain point, chopping it up doesn't help
   because we take a ceil_log2

   This should be done by setting iteratively making it higher.
*)
(* TODO: Remove this if I decide not to do it..
       
       We set all the deferred values in our public input to zero if
        we are in the base case.

        In the other proof, we will have

        prev_proof.deferred_values.marlin.alpha = 0

        iff

        that proof was a base case. Why?
    
        If prev_proof.deferred_values.marlin.alpha = 0, then either
        
        1. The previous proof was a base case.
        2. The actual alpha from the previous proof was 0.

        Let us argue that (2) is impossible (WOP).

        Inspecting the definition of incrementally_verify_proof,
        we see that marlin_actual.alpha is the output of a random oracle. Thus (WOP),
        marlin_actual.alpha is not 0.
    *)
