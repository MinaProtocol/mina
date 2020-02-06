(* q > p *)
module D = Digest
open Core_kernel
open Import
open Util
open Types.Pairing_based
open Pickles_types
open Common

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
      | Prev_app_state : 's Tag.t -> 's t
      | Prev_sg : G.Constant.t t
      | Prev_x_hat_beta_1 : Field.Constant.t t
      | Me_only :
          's Tag.t
          -> (G.Constant.t, 's) Pairing_based.Proof_state.Me_only.t t
      | Prev_proof_state :
          ( Challenge.Constant.t
          , Fp.Constant.t
          , bool
          , Challenge.Constant.t
          , Fq.Constant.t
          , Digest.Constant.t
          , Digest.Constant.t )
          Dlog_based.Proof_state.t
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
      , { Types.Bulletproof_challenge.prechallenge= pre
        ; is_square= pre_is_square } )
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

  let h_precomp = G.Scaling_precomputation.create Generators.h

  let check_bulletproof ~sponge ~xi ~combined_inner_product
      ~
      (* Corresponds to y in figure 7 of WTS *)
      (* sum_i r^i sum_j xi^j f_j(beta_i) *)
      (advice : _ Openings.Bulletproof.Advice.t)
      ~polynomials:(without_degree_bound, with_degree_bound)
      ~openings_proof:({lr; delta; z_1; z_2; sg} :
                        (Fq.t, G.t) Openings.Bulletproof.t) =
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

  let incrementally_verify_proof ~verification_key:(m : _ Abc.t Matrix_evals.t)
      ~xi ~sponge ~public_input ~sg_old ~combined_inner_product ~advice
      ~messages ~openings_proof =
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
      check_bulletproof ~sponge:sponge_before_evaluations ~xi
        ~combined_inner_product ~advice ~openings_proof
        ~polynomials:
          ( [ sg_old
            ; x_hat
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
    Array.map chals
      ~f:(fun {Types.Bulletproof_challenge.prechallenge; is_square} ->
        Data.bits (is_square :: prechallenge) )
    |> Array.reduce_exn ~f:Data.append

  module Marlin_checks = Marlin_checks.Make (Impl)

  let finalize_other_proof ~domain_k ~domain_h ~sponge
      ({xi; r; r_xi_sum; marlin} :
        _ Types.Dlog_based.Proof_state.Deferred_values.t) =
    let open Vector in
    let open Pairing_marlin_types in
    let evals =
      exists (Evals.typ Field.typ) ~request:(fun () -> Requests.Prev_evals)
    in
    let x_hat_beta_1 =
      exists Field.typ ~request:(fun () -> Requests.Prev_x_hat_beta_1)
    in
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

  module type App_state_intf = Intf.App_state_intf with module Impl := Impl

  type 's app_state = (module App_state_intf with type t = 's)

  let hash_me_only (type s) ((module A) : s app_state) ~index =
    let open Types.Pairing_based.Proof_state.Me_only in
    let after_index =
      let sponge = Sponge.create sponge_params in
      Array.iter (index_to_field_elements ~g:G.to_field_elements index)
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

  let main (type s) ((module A) as am : s app_state)
      ({ proof_state=
           { deferred_values=
               (* Fq values that we need the next verifier to check. *)
               { marlin
               ; combined_inner_product
               ; xi (* The batching challenge. *)
               ; bulletproof_challenges: (_, _) Types.Bulletproof_challenge.t
                                         array
               ; b }
           ; sponge_digest_before_evaluations
           ; was_base_case
           ; me_only= me_only_digest }
       ; pass_through } :
        _ Statement.t) =
    let me_only =
      exists
        ~request:(fun () -> Requests.Me_only A.Tag)
        (Types.Pairing_based.Proof_state.Me_only.typ G.typ A.typ)
    in
    let { Types.Pairing_based.Proof_state.Me_only.app_state
        ; dlog_marlin_index
        ; sg } =
      me_only
    in
    let hash_me_only = unstage (hash_me_only am ~index:dlog_marlin_index) in
    Field.Assert.equal me_only_digest (Field.pack (hash_me_only me_only)) ;
    let ( prev_deferred_values
        , prev_sponge_digest_before_evaluations
        , prev_proof_state ) =
      let state =
        exists
          (Types.Dlog_based.Proof_state.typ Challenge.typ Fp.typ Boolean.typ
             Fq.typ Digest.typ Digest.typ) ~request:(fun () ->
            Requests.Prev_proof_state )
      in
      ( Types.Dlog_based.Proof_state.Deferred_values.map_challenges ~f:Fp.pack
          state.deferred_values
      , Fp.pack state.sponge_digest_before_evaluations
      , state )
    in
    let prev_app_state =
      exists A.typ ~request:(fun () -> Requests.Prev_app_state A.Tag)
    in
    let sg_old = exists G.typ ~request:(fun () -> Requests.Prev_sg) in
    let prev_statement =
      let prev_me_only =
        hash_me_only {app_state= prev_app_state; dlog_marlin_index; sg= sg_old}
      in
      { Types.Dlog_based.Statement.pass_through= prev_me_only
      ; proof_state= prev_proof_state }
    in
    let prev_proof_finalized =
      let sponge =
        let s = Sponge.create sponge_params in
        Sponge.absorb s (`Field prev_sponge_digest_before_evaluations) ;
        s
      in
      finalize_other_proof ~domain_k ~domain_h ~sponge prev_deferred_values
    in
    let is_base_case = A.is_base_case app_state in
    let ( sponge_digest_before_evaluations_actual
        , (`Success bulletproof_success, bulletproof_challenges_actual)
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
      assert_equal_g openings_proof.sg sg ;
      let public_input =
        Array.append
          [|[Boolean.true_]|]
          (pack_data (Types.Dlog_based.Statement.to_data prev_statement))
      in
      let sponge = Sponge.create sponge_params in
      incrementally_verify_proof ~xi ~verification_key:dlog_marlin_index
        ~sponge ~public_input ~sg_old ~combined_inner_product ~advice:{b}
        ~messages ~openings_proof
    in
    Boolean.Assert.(is_base_case = was_base_case) ;
    let prev_proof_correct =
      print_bool "bulletproof_success" bulletproof_success ;
      print_bool "prev_proof_finalized" prev_proof_finalized ;
      print_bool "prev-was-base" prev_statement.proof_state.was_base_case ;
      let prev_proof_finalized =
        Boolean.(prev_proof_finalized || is_base_case)
      in
      let bulletproof_success =
        Boolean.(
          bulletproof_success || prev_statement.proof_state.was_base_case)
      in
      print_bool "prev_proof_finalized'" prev_proof_finalized ;
      print_bool "bulletproof_success''" bulletproof_success ;
      Boolean.all [bulletproof_success; prev_proof_finalized]
    in
    let update_succeeded = A.check_update prev_app_state app_state in
    print_bool "prev_proof_correct" prev_proof_correct ;
    print_bool "update succeeded" update_succeeded ;
    print_bool "is base" is_base_case ;
    ((* TODO Use the Data module here instead *)
     let fq (x1, b1) (x2, b2) =
       Field.Assert.equal x1 x2 ;
       Boolean.Assert.(b1 = b2)
     in
     let chal c1 c2 =
       Field.Assert.equal (Field.project c1) (Field.project c2)
     in
     fq marlin.sigma_2 marlin_actual.sigma_2 ;
     fq marlin.sigma_3 marlin_actual.sigma_3 ;
     chal marlin.alpha marlin_actual.alpha ;
     chal marlin.eta_a marlin_actual.eta_a ;
     chal marlin.eta_b marlin_actual.eta_b ;
     chal marlin.eta_c marlin_actual.eta_c ;
     chal marlin.beta_1 marlin_actual.beta_1 ;
     chal marlin.beta_2 marlin_actual.beta_2 ;
     chal marlin.beta_3 marlin_actual.beta_3 ;
     Array.iteri bulletproof_challenges ~f:(fun i c1 ->
         let c2 = bulletproof_challenges_actual.(i) in
         Boolean.Assert.( = ) c1.is_square
           (Boolean.if_ is_base_case ~then_:c1.is_square ~else_:c2.is_square) ;
         let c1 = Field.pack c1.prechallenge in
         let c2 =
           Field.if_ is_base_case ~then_:c1 ~else_:(Field.pack c2.prechallenge)
         in
         Field.Assert.equal c1 c2 ) ;
     Field.Assert.equal sponge_digest_before_evaluations
       (Field.pack sponge_digest_before_evaluations_actual)) ;
    Boolean.(Assert.any [prev_proof_correct && update_succeeded; is_base_case])

  (* TODO: The code here and in [pack_data] in dlog_main should be unified into
   one piece of code from which both functions are derived. *)
  let main am
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
          Types.Bulletproof_challenge.unpack
            (Fp.unpack ~length:(1 + Challenge.length) t) ) )
    |> Types.Pairing_based.Statement.of_data |> main am
end

(*
    Data.(
      (* TODO: Other stuff too... *)
        assert_equal
          ~field_size:Field.size_in_bits
          ~pack:Field.pack
          (fun expected computed ->
             let other = Field.if_ is_base_case ~then_:expected ~else_:computed in
             as_prover As_prover.(fun () ->

                 let expected = read_var expected in
                 let other = read_var other in
                 printf !"check %{sexp:Field.Constant.t} = %{sexp:Field.Constant.t}\n%!"
                   expected
                   other ;

                 printf !"x - y:%!";
                 Field.Constant.(print (expected - other));
                 printf !"\n%!";
                 printf !"y - x:%!";
                 Field.Constant.(print (other - expected));
                 printf !"\n%!";

                 assert (Field.Constant.equal expected other);
               ) ;
             Impl.assert_ ~label:"special"
               (Impl.Constraint.equal expected other) 
          )
          (marlin_data marlin)
          (marlin_data marlin_actual))
       *)
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
