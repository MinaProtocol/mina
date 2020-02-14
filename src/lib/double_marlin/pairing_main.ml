(* q > p *)
module D = Digest
open Core_kernel
open Import
open Util
open Types.Pairing_based
open Rugelach_types
open Common

module Main (Inputs : Intf.Pairing_main_inputs.S) = struct
  open Inputs
  open Impl
  module Branching = Nat.S (Branching_pred)
  module PC = G
  module Fp = Impl.Field
  module Challenge = Challenge.Make (Impl)
  module Digest = D.Make (Impl)

  (* q > p *)
  module Fq = struct
    let size_in_bits = Fp.size_in_bits

    module Constant = struct
      type t = Fq.t
    end

    type t = (* Low bits, high bit *)
      Fp.t * Boolean.var

    let typ =
      Typ.transport
        (Typ.tuple2 Fp.typ Boolean.typ)
        ~there:(fun x ->
          let low, high = Common.split_last (Fq.to_bits x) in
          (Fp.Constant.project low, high) )
        ~back:(fun (low, high) ->
          let low, _ = Common.split_last (Fp.Constant.unpack low) in
          Fq.of_bits (low @ [high]) )

    let to_bits (x, b) = Field.unpack x ~length:(Field.size_in_bits - 1) @ [b]
  end

  type 'a vec = ('a, Branching.n) Vector.t

  module Requests = struct
    open Snarky.Request
    open Types
    open Pairing_marlin_types

    module Compute = struct
      type _ t += Fq_is_square : bool list -> bool t
    end

    type _ t +=
      | Prev_evals : (Field.Constant.t Evals.t * Field.Constant.t) vec t
      | Prev_messages : (PC.Constant.t, Fq.Constant.t) Messages.t vec t
      | Prev_openings_proof :
          (Fq.Constant.t, G.Constant.t) Pairing_based.Openings.Bulletproof.t
          vec
          t
      | Prev_sg : G.Constant.t vec vec t
      | Me_only :
          's Tag.t
          -> ( G.Constant.t
             , 's
             , G.Constant.t vec )
             Pairing_based.Proof_state.Me_only.t
             t
      | Prev_states :
          's Tag.t
          -> ( ( Challenge.Constant.t
               , Fp.Constant.t
               , bool
               , Fq.Constant.t
               , Digest.Constant.t
               , Digest.Constant.t )
               Dlog_based.Proof_state.t
             * 's )
             vec
             t
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
        let t1, t2 = t in
        let absorb t = absorb sponge t in
        absorb ty1 t1 ; absorb ty2 t2

  let bullet_reduce sponge gammas =
    let absorb t = absorb sponge t in
    let prechallenges =
      Array.mapi gammas ~f:(fun i gammas_i ->
          absorb (PC :: PC) gammas_i ;
          Sponge.squeeze sponge ~length:Challenge.length )
    in
    let term_and_challenge (l, r) pre =
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
          G.if_ pre_is_square ~then_:l
            ~else_:(G.scale_by_quadratic_nonresidue l)
        in
        G.scale base pre
      in
      let right_term =
        let base =
          G.if_ pre_is_square ~then_:r
            ~else_:(G.scale_by_quadratic_nonresidue_inv r)
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

  let h_precomp = G.Scaling_precomputation.create Generators.h

  let (Nat.S _) = Branching.n

  let check_bulletproof ~domain_h ~domain_k ~sponge ~xi ~combined_inner_product
      ~
      (* Corresponds to y in figure 7 of WTS *)
      (* sum_i r^i sum_j xi^j f_j(beta_i) *)
      (advice : _ Openings.Bulletproof.Advice.t)
      ~polynomials:(without_degree_bound, with_degree_bound)
      ~openings_proof:({lr; delta; z_1; z_2; sg} :
                        (Fq.t, G.t) Openings.Bulletproof.t) =
    let dlog_pcs_batch =
      Common.dlog_pcs_batch ~domain_h ~domain_k (Branching.add Nat.N19.n)
    in
    (* a_hat should be equal to
       sum_i < t, r^i pows(beta_i) >
       = sum_i r^i < t, pows(beta_i) > *)
    let u =
      (* TODO sample u randomly *)
      G.one
    in
    let open G in
    let combined_polynomial (* Corresponds to xi in figure 7 of WTS *) =
      Pcs_batch.combine_commitments dlog_pcs_batch ~scale ~add:( + ) ~xi
        without_degree_bound with_degree_bound
    in
    let lr_prod, challenges = bullet_reduce sponge lr in
    let p_prime =
      combined_polynomial + scale u (Fq.to_bits combined_inner_product)
    in
    let q = p_prime + lr_prod in
    absorb sponge PC delta ;
    let c = Sponge.squeeze sponge ~length:Challenge.length in
    (* c Q + delta = z1 (G + b U) + z2 H *)
    let lhs = scale q c + delta in
    let rhs =
      let scale t x = scale t (Fq.to_bits x) in
      let b_u = scale u advice.b in
      let z_1_g_plus_b_u = scale (sg + b_u) z_1 in
      let z2_h = G.multiscale_known [|(Fq.to_bits z_2, h_precomp)|] in
      print_g "Ou" u ;
      print_g "Ob_u" b_u ;
      print_g "Oz1 (g + b u)" z_1_g_plus_b_u ;
      print_g "Oz2 h" z2_h ;
      z_1_g_plus_b_u + z2_h
    in
    print_chal "Oxi" xi ;
    print_g "Ocombined_polynomial" combined_polynomial ;
    print_g "Osg" sg ;
    print_chal "Oc" c ;
    print_g "Olr_prod" lr_prod ;
    print_g "Olhs" lhs ;
    print_g "Orhs" rhs ;
    (`Success (equal_g lhs rhs), challenges)

  let lagrange_precomputations =
    Array.map Input_domain.lagrange_commitments
      ~f:G.Scaling_precomputation.create

  let incrementally_verify_proof ~domain_h ~domain_k
      ~verification_key:(m : _ Abc.t Matrix_evals.t) ~xi ~sponge ~public_input
      ~(sg_old : _ vec) ~combined_inner_product ~advice ~messages
      ~openings_proof =
    let receive ty f =
      let x = f messages in
      absorb sponge ty x ; x
    in
    let sample () = Sponge.squeeze sponge ~length:Challenge.length in
    let open Pairing_marlin_types.Messages in
    let x_hat =
      assert (
        Int.ceil_pow2 (Array.length public_input)
        = Domain.size Input_domain.domain ) ;
      G.multiscale_known
        (Array.mapi public_input ~f:(fun i x ->
             (x, lagrange_precomputations.(i)) ))
    in
    absorb sponge PC x_hat ;
    let w_hat = receive PC w_hat in
    let z_hat_a = receive PC z_hat_a in
    let z_hat_b = receive PC z_hat_b in
    let alpha = sample () in
    let eta_a = sample () in
    let eta_b = sample () in
    let eta_c = sample () in
    let g_1, h_1 = receive ((PC :: PC) :: PC) gh_1 in
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
      (* TODO:
         This sponge needs to be initialized with (some derivative of)
         1. The polynomial commitments
         2. The combined inner product
         3. The challenge points.

         It should be sufficient to fork the sponge after squeezing beta_3 and then to absorb
         the combined inner product. 
      *)
      let without_degree_bound =
        Vector.append sg_old
          [ x_hat
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
      check_bulletproof ~domain_h ~domain_k ~sponge:sponge_before_evaluations
        ~xi ~combined_inner_product ~advice ~openings_proof
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

  module Marlin_checks = Marlin_checks.Make (Impl)

  let finalize_other_proof ~domain_k ~domain_h ~sponge
      ({xi; r; r_xi_sum; marlin} :
        _ Types.Dlog_based.Proof_state.Deferred_values.t) (evals, x_hat_beta_1)
      =
    let open Vector in
    let open Pairing_marlin_types in
    let absorb_field x = Sponge.absorb sponge (`Field x) in
    absorb_field x_hat_beta_1 ;
    Vector.iter (Evals.to_vector evals) ~f:absorb_field ;
    let open Fp in
    let xi_actual = Sponge.squeeze sponge ~length:Challenge.length in
    let r_actual = Sponge.squeeze sponge ~length:Challenge.length in
    let combined_evaluation batch pt without_bound =
      Pcs_batch.combine_evaluations batch ~crs_max_degree ~mul ~add ~one
        ~evaluation_point:pt ~xi without_bound []
    in
    let beta1, beta2, beta3 =
      Evals.to_combined_vectors ~x_hat:x_hat_beta_1 evals
    in
    let xi_correct = Fp.equal (Field.pack xi_actual) xi in
    let r_correct = Fp.equal (Field.pack r_actual) r in
    let r_xi_sum_correct =
      let r_xi_sum_actual =
        r
        * ( combined_evaluation Common.pairing_beta_1_pcs_batch marlin.beta_1
              beta1
          + r
            * ( combined_evaluation Common.pairing_beta_2_pcs_batch
                  marlin.beta_2 beta2
              + r
                * combined_evaluation Common.pairing_beta_3_pcs_batch
                    marlin.beta_3 beta3 ) )
      in
      Fp.equal r_xi_sum r_xi_sum_actual
    in
    let marlin_checks =
      Marlin_checks.check ~x_hat_beta_1 ~input_domain:Input_domain.self
        ~domain_h ~domain_k marlin evals
    in
    as_prover
      As_prover.(
        fun () ->
          if not (read Boolean.typ r_correct) then (
            print_fp "r" r ;
            print_fp "r_actual" (Field.pack r_actual) )) ;
    as_prover
      As_prover.(
        fun () ->
          if not (read Boolean.typ xi_correct) then (
            print_fp "xi" xi ;
            print_fp "xi_actual" (Field.pack xi_actual) )) ;
    List.iter
      ~f:(Tuple2.uncurry (Fn.flip print_bool))
      [ (xi_correct, "xi_correct")
      ; (r_correct, "r_correct")
      ; (r_xi_sum_correct, "r_xi_sum_correct")
      ; (marlin_checks, "marlin_checks") ] ;
    Boolean.all [xi_correct; r_correct; r_xi_sum_correct; marlin_checks]

  module type App_state_intf =
    Intf.App_state_intf
    with module Impl := Impl
     and module Branching := Branching

  type 's app_state = (module App_state_intf with type t = 's)

  let hash_me_only (type s) ((module A) : s app_state) ~index =
    let open Types.Pairing_based.Proof_state.Me_only in
    let after_index =
      let sponge = Sponge.create sponge_params in
      Array.iter (Types.index_to_field_elements ~g:G.to_field_elements index)
        ~f:(fun x -> Sponge.absorb sponge (`Field x)) ;
      sponge
    in
    stage (fun t ->
        let sponge = Sponge.copy after_index in
        Array.iter
          ~f:(fun x -> Sponge.absorb sponge (`Field x))
          (to_field_elements_without_index t ~app_state:A.to_field_elements
             ~g:G.to_field_elements) ;
        Sponge.squeeze sponge ~length:Digest.length )

  let pack_data (bool, fp, challenge, digest) =
    Array.concat
      [ Array.map (Vector.to_array bool) ~f:List.return
      ; Array.of_list_map (Vector.to_list fp) ~f:(fun x ->
            let t =
              Bitstring_lib.Bitstring.Lsb_first.to_list (Fp.unpack_full x)
            in
            t )
      ; Vector.to_array challenge
      ; Vector.to_array digest ]

  let vec typ = Vector.typ typ Branching.n

  let assert_eq_marlin m1 m2 =
    let open Types.Dlog_based.Proof_state.Deferred_values.Marlin in
    let fq (x1, b1) (x2, b2) =
      Field.Assert.equal x1 x2 ;
      Boolean.Assert.(b1 = b2)
    in
    let chal c1 c2 = Field.Assert.equal c1 (Field.project c2) in
    fq m1.sigma_2 m2.sigma_2 ;
    fq m1.sigma_3 m2.sigma_3 ;
    chal m1.alpha m2.alpha ;
    chal m1.eta_a m2.eta_a ;
    chal m1.eta_b m2.eta_b ;
    chal m1.eta_c m2.eta_c ;
    chal m1.beta_1 m2.beta_1 ;
    chal m1.beta_2 m2.beta_2 ;
    chal m1.beta_3 m2.beta_3

  let main ~bulletproof_log2 ~domain_h ~domain_k (type s)
      ((module A) as am : s app_state)
      ({ proof_state=
           {unfinalized_proofs; me_only= me_only_digest; was_base_case}
       ; pass_through } :
        _ Statement.t) =
    let me_only =
      exists
        ~request:(fun () -> Requests.Me_only A.Tag)
        (Types.Pairing_based.Proof_state.Me_only.typ G.typ A.typ Branching.n)
    in
    let { Types.Pairing_based.Proof_state.Me_only.app_state
        ; dlog_marlin_index
        ; sg } =
      me_only
    in
    let hash_me_only = unstage (hash_me_only am ~index:dlog_marlin_index) in
    Field.Assert.equal me_only_digest (Field.pack (hash_me_only me_only)) ;
    let prev_states =
      exists
        (vec
           (Typ.tuple2
              (Types.Dlog_based.Proof_state.typ Challenge.typ Fp.typ
                 Boolean.typ Fq.typ Digest.typ Digest.typ)
              A.typ))
        ~request:(fun () -> Requests.Prev_states A.Tag)
    in
    (* TODO: Just group this with prev_states *)
    let sg_old =
      exists (vec (vec G.typ)) ~request:(fun () -> Requests.Prev_sg)
    in
    let prev_statements =
      Vector.map2 prev_states sg_old ~f:(fun (proof_state, app_state) sg ->
          let prev_me_only = hash_me_only {app_state; dlog_marlin_index; sg} in
          {Types.Dlog_based.Statement.pass_through= prev_me_only; proof_state}
      )
    in
    let prev_evals =
      let open Pairing_marlin_types in
      exists
        (vec (Typ.tuple2 (Evals.typ Field.typ) Field.typ))
        ~request:(fun () -> Requests.Prev_evals)
    in
    let prev_proofs_finalized =
      let sponge_digests =
        Vector.map prev_states ~f:(fun (s, _) ->
            Fp.pack s.sponge_digest_before_evaluations )
      in
      Vector.mapn [prev_states; sponge_digests; prev_evals]
        ~f:(fun [(s, _); sponge_digest; evals] ->
          let prev_deferred_values =
            Types.Dlog_based.Proof_state.Deferred_values.map_challenges
              ~f:Fp.pack s.deferred_values
          in
          let sponge =
            let sponge = Sponge.create sponge_params in
            Sponge.absorb sponge (`Field sponge_digest) ;
            sponge
          in
          finalize_other_proof ~domain_k ~domain_h ~sponge prev_deferred_values
            evals )
      |> Vector.to_list |> Boolean.all
    in
    let is_base_case = A.is_base_case app_state in
    let prev_was_base_case =
      Vector.map prev_statements ~f:(fun s -> s.proof_state.was_base_case)
      |> Vector.to_list |> Boolean.all
    in
    let messages =
      exists
        (vec (Pairing_marlin_types.Messages.typ PC.typ Fq.typ))
        ~request:(fun () -> Requests.Prev_messages)
    in
    let openings_proof =
      exists
        (vec
           (Types.Pairing_based.Openings.Bulletproof.typ Fq.typ G.typ
              ~length:bulletproof_log2))
        ~request:(fun () -> Requests.Prev_openings_proof)
    in
    let bulletproof_success =
      Vector.mapn
        [ prev_statements
        ; sg
        ; sg_old
        ; messages
        ; openings_proof
        ; unfinalized_proofs ]
        ~f:(fun [ statement
                ; sg
                ; sg_old
                ; messages
                ; opening
                ; (unfinalized : _ Types.Pairing_based.Proof_state.Per_proof.t)
                ]
           ->
          assert_equal_g opening.sg sg ;
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
            let xi = Field.unpack ~length:Challenge.length xi in
            incrementally_verify_proof ~domain_h ~domain_k ~xi
              ~verification_key:dlog_marlin_index ~sponge ~public_input ~sg_old
              ~combined_inner_product ~advice:{b} ~messages
              ~openings_proof:opening
          in
          Field.Assert.equal unfinalized.sponge_digest_before_evaluations
            (Fp.pack sponge_digest_before_evaluations_actual) ;
          assert_eq_marlin unfinalized.deferred_values.marlin marlin_actual ;
          Array.iteri
            (Vector.to_array unfinalized.deferred_values.bulletproof_challenges)
            ~f:(fun i c1 ->
              let c2 = bulletproof_challenges_actual.(i) in
              Boolean.Assert.( = ) c1.Bulletproof_challenge.is_square
                (Boolean.if_ is_base_case ~then_:c1.is_square
                   ~else_:c2.is_square) ;
              let c1 = Field.pack c1.prechallenge in
              let c2 =
                Field.if_ is_base_case ~then_:c1
                  ~else_:(Field.pack c2.prechallenge)
              in
              Field.Assert.equal c1 c2 ) ;
          bulletproof_success )
      |> Vector.to_list |> Boolean.all
    in
    Boolean.Assert.(is_base_case = was_base_case) ;
    let prev_proof_correct =
      print_bool "bulletproof_success" bulletproof_success ;
      print_bool "prev_proof_finalized" prev_proofs_finalized ;
      print_bool "prev-was-base" prev_was_base_case ;
      let prev_proof_finalized =
        Boolean.(prev_proofs_finalized || is_base_case)
      in
      let bulletproof_success =
        Boolean.(bulletproof_success || prev_was_base_case)
      in
      print_bool "prev_proof_finalized'" prev_proof_finalized ;
      print_bool "bulletproof_success''" bulletproof_success ;
      Boolean.all [bulletproof_success; prev_proof_finalized]
    in
    let update_succeeded =
      A.check_update (Vector.map prev_states ~f:snd) app_state
    in
    print_bool "prev_proof_correct" prev_proof_correct ;
    print_bool "update succeeded" update_succeeded ;
    print_bool "is base" is_base_case ;
    Boolean.(Assert.any [prev_proof_correct && update_succeeded; is_base_case])
end
