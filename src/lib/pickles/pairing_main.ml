(* q > p *)
open Core_kernel
open Import
open Util
open Types.Pairing_based
module SC = Scalar_challenge
open Pickles_types
open Common
open Import
module S = Sponge

module Make
    (Inputs : Intf.Pairing_main_inputs.S
              with type Impl.field = Backend.Tick.Field.t
               and type Inner_curve.Constant.Scalar.t = Backend.Tock.Field.t) =
struct
  open Inputs
  open Impl
  module PC = Inner_curve
  module Challenge = Challenge.Make (Impl)
  module Digest = Digest.Make (Impl)

  (* Other_field.size > Field.size *)
  module Other_field = struct
    let size_in_bits = Field.size_in_bits

    module Constant = Other_field

    type t = (* Low bits, high bit *)
      Field.t * Boolean.var

    let typ =
      Typ.transport
        (Typ.tuple2 Field.typ Boolean.typ)
        ~there:(fun x ->
          let low, high = Util.split_last (Other_field.to_bits x) in
          (Field.Constant.project low, high) )
        ~back:(fun (low, high) ->
          let low, _ = Util.split_last (Field.Constant.unpack low) in
          Other_field.of_bits (low @ [high]) )

    let to_bits (x, b) = Field.unpack x ~length:(Field.size_in_bits - 1) @ [b]
  end

  let print_g lab g =
    if debug then
      as_prover
        As_prover.(
          fun () ->
            match Inner_curve.to_field_elements g with
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
          Field.Constant.print (As_prover.read Field.typ x) ;
          printf "\n%!" )

  let print_bool lab x =
    if debug then
      as_prover (fun () ->
          printf "%s: %b\n%!" lab (As_prover.read Boolean.typ x) )

  let equal_g g1 g2 =
    List.map2_exn ~f:Field.equal
      (Inner_curve.to_field_elements g1)
      (Inner_curve.to_field_elements g2)
    |> Boolean.all

  let absorb sponge ty t =
    absorb
      ~absorb_field:(fun x -> Sponge.absorb sponge (`Field x))
      ~g1_to_field_elements:Inner_curve.to_field_elements
      ~absorb_scalar:(fun (low_bits, high_bit) ->
        Sponge.absorb sponge (`Field low_bits) ;
        Sponge.absorb sponge (`Bits [high_bit]) )
      ty t

  module Scalar_challenge = SC.Make (Impl) (Inner_curve) (Challenge) (Endo.Dee)

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
                Other_field.Constant.(
                  is_square
                    (Scalar_challenge.Constant.to_field
                       (read Scalar_challenge.typ pre))))
      in
      let left_term =
        let base =
          Inner_curve.if_ pre_is_square ~then_:l
            ~else_:(Inner_curve.scale_by_quadratic_nonresidue l)
        in
        Scalar_challenge.endo base pre
      in
      let right_term =
        let base =
          Inner_curve.if_ pre_is_square ~then_:r
            ~else_:(Inner_curve.scale_by_quadratic_nonresidue_inv r)
        in
        Scalar_challenge.endo_inv base pre
      in
      ( Inner_curve.(left_term + right_term)
      , {Bulletproof_challenge.prechallenge= pre; is_square= pre_is_square} )
    in
    let terms, challenges =
      Array.map2_exn gammas prechallenges ~f:term_and_challenge |> Array.unzip
    in
    (Array.reduce_exn terms ~f:Inner_curve.( + ), challenges)

  let h_precomp =
    Lazy.map ~f:Inner_curve.Scaling_precomputation.create Generators.h

  let group_map =
    let f =
      lazy
        (let module M =
           Group_map.Bw19.Make (Field.Constant) (Field)
             (struct
               let params =
                 Group_map.Bw19.Params.create
                   (module Field.Constant)
                   {b= Inner_curve.Params.b}
             end)
         in
        let open M in
        Snarky_group_map.Checked.wrap
          (module Impl)
          ~potential_xs
          ~y_squared:(fun ~x ->
            Field.(
              (x * x * x)
              + (constant Inner_curve.Params.a * x)
              + constant Inner_curve.Params.b) )
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
                        (Inner_curve.t, Other_field.t) Openings.Bulletproof.t)
      =
    with_label __LOC__ (fun () ->
        (* a_hat should be equal to
       sum_i < t, r^i pows(beta_i) >
       = sum_i r^i < t, pows(beta_i) > *)
        let u =
          let t = Sponge.squeeze_field sponge in
          group_map t
        in
        let open Inner_curve in
        let combined_polynomial (* Corresponds to xi in figure 7 of WTS *) =
          Pcs_batch.combine_split_commitments pcs_batch
            ~scale_and_add:(fun ~acc ~xi p -> p + Scalar_challenge.endo acc xi)
            ~xi ~init:Fn.id without_degree_bound with_degree_bound
        in
        let lr_prod, challenges = bullet_reduce sponge lr in
        let p_prime =
          combined_polynomial
          + scale u (Other_field.to_bits combined_inner_product)
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
          let scale t x = scale t (Other_field.to_bits x) in
          let b_u = scale u advice.b in
          let z_1_g_plus_b_u = scale (sg + b_u) z_1 in
          let z2_h =
            Inner_curve.multiscale_known
              [|(Other_field.to_bits z_2, Lazy.force h_precomp)|]
          in
          z_1_g_plus_b_u + z2_h
        in
        (`Success (equal_g lhs rhs), challenges) )

  let lagrange_precomputations =
    lazy
      (Array.map
         (Lazy.force Input_domain.lagrange_commitments)
         ~f:Inner_curve.Scaling_precomputation.create)

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
          let input_size = Array.length public_input in
          assert (Int.ceil_pow2 input_size = Domain.size Input_domain.domain) ;
          Inner_curve.multiscale_known
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
        let sponge_digest_before_evaluations = Sponge.squeeze_field sponge in
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

  let compute_challenges ~scalar chals =
    (* TODO: Put this in the functor argument. *)
    let nonresidue = Field.of_int 5 in
    Vector.map chals ~f:(fun {Bulletproof_challenge.prechallenge; is_square} ->
        let pre = scalar prechallenge in
        let sq =
          Field.if_ is_square ~then_:pre ~else_:Field.(nonresidue * pre)
        in
        (* TODO: Make deterministic *)
        Field.sqrt sq )

  let b_poly = Field.(Dlog_main.b_poly ~add ~mul ~inv)

  module Pseudo = Pseudo.Make (Impl)

  let crs_max_degree = 1 lsl Nat.to_int Backend.Rounds.n

  module Split_evaluations = struct
    open Dlog_marlin_types

    let mask (type n) ~(lengths : (int, n) Vector.t)
        (choice : n One_hot_vector.T(Impl).t) : Boolean.var array =
      let max =
        Option.value_exn
          (List.max_elt ~compare:Int.compare (Vector.to_list lengths))
      in
      let length = Pseudo.choose (choice, lengths) ~f:Field.of_int in
      let (T max) = Nat.of_int max in
      Vector.to_array (ones_vector (module Impl) ~first_zero:length max)

    let last =
      Array.reduce_exn ~f:(fun (b_acc, x_acc) (b, x) ->
          (Boolean.(b_acc || b), Field.if_ b ~then_:x ~else_:x_acc) )

    let combine_split_evaluations' b_plus_19 ~step_domains ~which_branch =
      let h_minus_1 =
        ( which_branch
        , Vector.map step_domains ~f:(fun x -> Domain.size x.Domains.h - 1) )
      in
      let k_minus_1 =
        ( which_branch
        , Vector.map step_domains ~f:(fun x -> Domain.size x.Domains.k - 1) )
      in
      Pcs_batch.combine_split_evaluations ~last
        ~mul:(fun (keep, x) (y : Field.t) -> (keep, Field.(y * x)))
        ~mul_and_add:(fun ~acc ~xi (keep, fx) ->
          Field.if_ keep ~then_:Field.(fx + (xi * acc)) ~else_:acc )
        ~init:(fun (_, fx) -> fx)
        (Common.dlog_pcs_batch b_plus_19 ~h_minus_1 ~k_minus_1)
        ~shifted_pow:(Pseudo.Degree_bound.shifted_pow ~crs_max_degree)

    let mask_evals (type n) ~(lengths : (int, n) Vector.t Evals.t)
        (choice : n One_hot_vector.T(Impl).t) (e : Field.t array Evals.t) :
        (Boolean.var * Field.t) array Evals.t =
      Evals.map2 lengths e ~f:(fun lengths e ->
          Array.zip_exn (mask ~lengths choice) e )
  end

  let combined_evaluation (type b b_plus_19) b_plus_19 ~xi ~evaluation_point
      ((without_degree_bound : (_, b_plus_19) Vector.t), with_degree_bound)
      ~h_minus_1 ~k_minus_1 =
    let open Field in
    Pcs_batch.combine_split_evaluations ~mul
      ~mul_and_add:(fun ~acc ~xi fx -> fx + (xi * acc))
      ~shifted_pow:(Pseudo.Degree_bound.shifted_pow ~crs_max_degree)
      ~init:Fn.id ~evaluation_point ~xi
      (Common.dlog_pcs_batch b_plus_19 ~h_minus_1 ~k_minus_1)
      without_degree_bound with_degree_bound

  let absorb_field sponge x = Sponge.absorb sponge (`Field x)

  let pack_scalar_challenge (Pickles_types.Scalar_challenge.Scalar_challenge t)
      =
    Field.pack (Challenge.to_bits t)

  let actual_evaluation (e : (Boolean.var * Field.t) array) (pt : Field.t) :
      Field.t =
    let pt_n =
      let max_degree_log2 = Int.ceil_log2 crs_max_degree in
      let rec go acc i =
        if i = 0 then acc else go (Field.square acc) (i - 1)
      in
      go pt max_degree_log2
    in
    match List.rev (Array.to_list e) with
    | (b, e) :: es ->
        List.fold
          ~init:Field.((b :> t) * e)
          es
          ~f:(fun acc (keep, fx) ->
            (* Field.(y + (pt_n * acc))) *)
            Field.if_ keep ~then_:Field.(fx + (pt_n * acc)) ~else_:acc )
    | [] ->
        failwith "empty list"

  open Dlog_marlin_types

  module Opt_sponge = struct
    module Underlying = Opt_sponge.Make (Impl)

    include S.Bit_sponge.Make (struct
                type t = Boolean.var
              end)
              (struct
                type t = Field.t

                let to_bits =
                  Field.choose_preimage_var ~length:Field.size_in_bits

                let high_entropy_bits = Step_main_inputs.high_entropy_bits
              end)
              (struct
                type t = Boolean.var * Field.t
              end)
              (Underlying)
  end

  (* This finalizes the "deferred values" coming from a previous proof over the same field.
   It 
   1. Checks that [xi] and [r] where sampled correctly. I.e., by absorbing all the
   evaluation openings and then squeezing.
   2. Checks that the "combined inner product" value used in the elliptic curve part of
   the opening proof was computed correctly, in terms of the evaluation openings and the
   evaluation points.
   3. Check that the "b" value was computed correctly.
   4. Perform the arithmetic checks from marlin. *)
  (* TODO: This needs to handle the fact of variable length evaluations.
   Meaning it needs opt sponge. *)
  let finalize_other_proof (type b branches)
      (module Branching : Nat.Add.Intf with type n = b) ~step_domains
      ~step_widths
      ~(* TODO: Add "actual branching" so that proofs don't
   carry around dummy "old bulletproof challenges" *)

       (*
      ~domain_h ~domain_k
      ~h_minus_1 ~k_minus_1 *)
      input_domain ~sponge ~(old_bulletproof_challenges : (_, b) Vector.t)
      ({ xi
       ; combined_inner_product
       ; bulletproof_challenges
       ; which_branch
       ; b
       ; marlin } :
        _ Types.Dlog_based.Proof_state.Deferred_values.t) es =
    let open Vector in
    let actual_width =
      Pseudo.choose (which_branch, step_widths) ~f:Field.of_int
    in
    let hs = map step_domains ~f:(fun {Domains.h; _} -> h) in
    let ks = map step_domains ~f:(fun {Domains.k; _} -> k) in
    let lengths =
      Commitment_lengths.generic map ~h:(map hs ~f:Domain.size)
        ~k:(map ks ~f:Domain.size)
    in
    let (beta_1_evals, x_hat1), (beta_2_evals, x_hat2), (beta_3_evals, x_hat3)
        =
      Tuple_lib.Triple.map es ~f:(fun (e, x) ->
          ( Split_evaluations.mask_evals ~lengths
              (which_branch : branches One_hot_vector.T(Impl).t)
              e
          , x ) )
    in
    let T = Branching.eq in
    (* You use the NEW bulletproof challenges to check b. Not the old ones. *)
    let open Field in
    let absorb_evals x_hat e =
      let xs, ys = Evals.to_vectors e in
      List.iter
        Vector.([|(Boolean.true_, x_hat)|] :: (to_list xs @ to_list ys))
        ~f:(Array.iter ~f:(Opt_sponge.absorb sponge))
    in
    (* A lot of hashing. *)
    absorb_evals x_hat1 beta_1_evals ;
    absorb_evals x_hat2 beta_2_evals ;
    absorb_evals x_hat3 beta_3_evals ;
    let xi_actual = Opt_sponge.squeeze sponge ~length:Challenge.length in
    let r_actual = Opt_sponge.squeeze sponge ~length:Challenge.length in
    let xi_correct = equal (pack xi_actual) (pack_scalar_challenge xi) in
    let scalar = SC.to_field_checked (module Impl) ~endo:Endo.Dum.scalar in
    let marlin =
      Types.Pairing_based.Proof_state.Deferred_values.Marlin.map_challenges
        ~f:Field.pack ~scalar marlin
    in
    let xi = scalar xi in
    let r = scalar (Scalar_challenge r_actual) in
    let combined_inner_product_correct =
      (* sum_i r^i sum_j xi^j f_j(beta_i) *)
      let actual_combined_inner_product =
        let sg_olds =
          Vector.map old_bulletproof_challenges ~f:(fun chals ->
              unstage (b_poly (Vector.to_array chals)) )
        in
        let combine pt x_hat e =
          let pi = Branching.add Nat.N19.n in
          let a, b =
            Evals.to_vectors (e : (Boolean.var * Field.t) array Evals.t)
          in
          let sg_evals =
            Vector.map2
              (ones_vector (module Impl) ~first_zero:actual_width Branching.n)
              sg_olds
              ~f:(fun keep f -> [|(keep, f pt)|])
          in
          let v =
            Vector.append sg_evals ([|(Boolean.true_, x_hat)|] :: a) (snd pi)
          in
          Split_evaluations.combine_split_evaluations' pi ~xi
            ~evaluation_point:pt ~step_domains ~which_branch v b
        in
        combine marlin.beta_1 x_hat1 beta_1_evals
        + r
          * ( combine marlin.beta_2 x_hat2 beta_2_evals
            + (r * combine marlin.beta_3 x_hat3 beta_3_evals) )
      in
      equal combined_inner_product actual_combined_inner_product
    in
    let bulletproof_challenges =
      compute_challenges ~scalar bulletproof_challenges
    in
    let b_correct =
      let b_poly = unstage (b_poly (Vector.to_array bulletproof_challenges)) in
      let b_actual =
        b_poly marlin.beta_1
        + (r * (b_poly marlin.beta_2 + (r * b_poly marlin.beta_3)))
      in
      equal b b_actual
    in
    let marlin_checks_passed =
      let e = actual_evaluation in
      Marlin_checks.checked
        (module Impl)
        ~input_domain
        ~domain_h:(Pseudo.Domain.to_domain (which_branch, hs))
        ~domain_k:(Pseudo.Domain.to_domain (which_branch, ks))
        ~x_hat_beta_1:x_hat1 marlin
        { w_hat= e beta_1_evals.w_hat marlin.beta_1
        ; g_1= e beta_1_evals.g_1 marlin.beta_1
        ; h_1= e beta_1_evals.h_1 marlin.beta_1
        ; z_hat_a= e beta_1_evals.z_hat_a marlin.beta_1
        ; z_hat_b= e beta_1_evals.z_hat_b marlin.beta_1
        ; g_2= e beta_2_evals.g_2 marlin.beta_2
        ; h_2= e beta_2_evals.h_2 marlin.beta_2
        ; g_3= e beta_3_evals.g_3 marlin.beta_3
        ; h_3= e beta_3_evals.h_3 marlin.beta_3
        ; row= Abc.map beta_3_evals.row ~f:(Fn.flip e marlin.beta_3)
        ; col= Abc.map beta_3_evals.col ~f:(Fn.flip e marlin.beta_3)
        ; value= Abc.map beta_3_evals.value ~f:(Fn.flip e marlin.beta_3)
        ; rc= Abc.map beta_3_evals.rc ~f:(Fn.flip e marlin.beta_3) }
    in
    print_bool "xi_correct" xi_correct ;
    print_bool "combined_inner_product_correct" combined_inner_product_correct ;
    print_bool "marlin_checks_passed" marlin_checks_passed ;
    print_bool "b_correct" b_correct ;
    ( Boolean.all
        [ xi_correct
        ; b_correct
        ; combined_inner_product_correct
        ; marlin_checks_passed ]
    , bulletproof_challenges )

  let hash_me_only (type s) ~index
      (state_to_field_elements : s -> Field.t array) =
    let open Types.Pairing_based.Proof_state.Me_only in
    let after_index =
      let sponge = Sponge.create sponge_params in
      Array.iter
        (Types.index_to_field_elements
           ~g:
             (fun (z :
                    Inputs.Inner_curve.t
                    Dlog_marlin_types.Poly_comm.Without_degree_bound.t) ->
             List.concat_map (Array.to_list z) ~f:Inner_curve.to_field_elements
             )
           index)
        ~f:(fun x -> Sponge.absorb sponge (`Field x)) ;
      sponge
    in
    stage (fun (t : _ Types.Pairing_based.Proof_state.Me_only.t) ->
        let sponge = Sponge.copy after_index in
        Array.iter
          ~f:(fun x -> Sponge.absorb sponge (`Field x))
          (to_field_elements_without_index t ~app_state:state_to_field_elements
             ~g:Inner_curve.to_field_elements) ;
        Sponge.squeeze_field sponge )

  let hash_me_only_opt (type s) ~index
      (state_to_field_elements : s -> Field.t array) =
    let open Types.Pairing_based.Proof_state.Me_only in
    let after_index =
      let sponge = Sponge.create sponge_params in
      Array.iter
        (Types.index_to_field_elements
           ~g:
             (fun (z :
                    Inputs.Inner_curve.t
                    Dlog_marlin_types.Poly_comm.Without_degree_bound.t) ->
             List.concat_map (Array.to_list z) ~f:Inner_curve.to_field_elements
             )
           index)
        ~f:(fun x -> Sponge.absorb sponge (`Field x)) ;
      sponge
    in
    stage (fun t ~widths ~max_width ~which_branch ->
        let mask =
          ones_vector
            (module Impl)
            max_width
            ~first_zero:(Pseudo.choose ~f:Field.of_int (which_branch, widths))
        in
        let sponge = Sponge.copy after_index in
        let t =
          { t with
            old_bulletproof_challenges=
              Vector.map2 mask t.old_bulletproof_challenges ~f:(fun b v ->
                  Vector.map v ~f:(fun x -> `Opt (b, x)) )
          ; sg= Vector.map2 mask t.sg ~f:(fun b g -> (b, g)) }
        in
        let not_opt x = `Not_opt x in
        let hash_inputs =
          to_field_elements_without_index t
            ~app_state:
              (Fn.compose (Array.map ~f:not_opt) state_to_field_elements)
            ~g:(fun (b, g) ->
              List.map
                ~f:(fun x -> `Opt (b, x))
                (Inner_curve.to_field_elements g) )
        in
        match
          Array.fold hash_inputs ~init:(`Not_opt sponge) ~f:(fun acc t ->
              match (acc, t) with
              | `Not_opt sponge, `Not_opt t ->
                  Sponge.absorb sponge (`Field t) ;
                  acc
              | `Not_opt sponge, `Opt t ->
                  let sponge =
                    S.Bit_sponge.map sponge ~f:Opt_sponge.Underlying.of_sponge
                  in
                  Opt_sponge.absorb sponge t ; `Opt sponge
              | `Opt sponge, `Opt t ->
                  Opt_sponge.absorb sponge t ; acc
              | `Opt _, `Not_opt _ ->
                  assert false )
        with
        | `Not_opt _ ->
            assert false
        | `Opt sponge ->
            Opt_sponge.squeeze_field sponge )

  (*
        Array.iter
          ~f:(fun x -> Sponge.absorb sponge (`Field x))
           ;
        Sponge.squeeze sponge ~length:Digest.length )
*)

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
        , Other_field.t )
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
        [|Bitstring_lib.Bitstring.Lsb_first.to_list (Field.unpack_full x)|]
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
          sponge_digest_before_evaluations_actual ;
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

include Make (Step_main_inputs)
