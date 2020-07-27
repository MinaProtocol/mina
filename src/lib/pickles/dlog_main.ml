module type Inputs = Intf.Wrap_main_inputs.S

module S = Sponge
open Backend
open Core_kernel
open Import
open Util
module SC = Scalar_challenge
open Pickles_types
open Dlog_marlin_types
module Accumulator = Pairing_marlin_types.Accumulator
open Tuple_lib
open Import

(* given [chals], compute
   \prod_i (1 / chals.(i) + chals.(i) * x^{2^i}) *)
let b_poly ~add ~mul ~inv chals =
  let ( + ) = add and ( * ) = mul in
  let chal_invs = Array.map chals ~f:inv in
  stage (fun pt ->
      let k = Array.length chals in
      let pow_two_pows =
        let res = Array.init k ~f:(fun _ -> pt) in
        for i = 1 to k - 1 do
          let y = res.(i - 1) in
          res.(i) <- y * y
        done ;
        res
      in
      let prod f =
        let r = ref (f 0) in
        for i = 1 to k - 1 do
          r := f i * !r
        done ;
        !r
      in
      prod (fun i -> chal_invs.(i) + (chals.(i) * pow_two_pows.(k - 1 - i))) )

module Make
    (Inputs : Inputs
              with type Impl.field = Tock.Field.t
               and type Inner_curve.Constant.Scalar.t = Tick.Field.t) =
struct
  open Inputs
  open Impl

  module Other_field = struct
    (* For us, p > q, so one Field.t = fp can represent an fq *)
    module Packed = struct
      module Constant = Other_field

      type t = Field.t

      let typ =
        Typ.transport Field.typ
          ~there:(fun (x : Constant.t) ->
            Bigint.to_field (Other_field.to_bigint x) )
          ~back:(fun (x : Field.Constant.t) ->
            Other_field.of_bigint (Bigint.of_field x) )

      (* TODO: Assert less than the length *)
      let to_bits = Field.choose_preimage_var ~length:Field.size_in_bits
    end

    module Unpacked = struct
      type t = Boolean.var list

      type constant = bool list

      let typ : (t, constant) Typ.t =
        let typ = Typ.list ~length:Field.size_in_bits Boolean.typ in
        let p_msb =
          let test_bit x i = B.(shift_right x i land one = one) in
          List.init Other_field.size_in_bits ~f:(test_bit Other_field.size)
          |> List.rev
        in
        let check xs_lsb =
          let open Bitstring_lib.Bitstring in
          Snarky.Checked.all_unit
            [ typ.check xs_lsb
            ; make_checked (fun () ->
                  Bitstring_checked.lt_value
                    (Msb_first.of_list (List.rev xs_lsb))
                    (Msb_first.of_list p_msb)
                  |> Boolean.Assert.is_true ) ]
        in
        {typ with check}

      let assert_equal t1 t2 = Field.(Assert.equal (project t1) (project t2))
    end

    let pack : Unpacked.t -> Packed.t = Field.project
  end

  let print_g1 lab (x, y) =
    if debug then
      as_prover
        As_prover.(
          fun () ->
            Core.printf "in-snark: %s (%s, %s)\n%!" lab
              (Field.Constant.to_string (read_var x))
              (Field.Constant.to_string (read_var y)))

  let print_chal lab x =
    if debug then
      as_prover
        As_prover.(
          fun () ->
            Core.printf "in-snark %s: %s\n%!" lab
              (Field.Constant.to_string
                 (Field.Constant.project (List.map ~f:(read Boolean.typ) x))))

  let print_bool lab x =
    if debug then
      as_prover (fun () ->
          printf "%s: %b\n%!" lab (As_prover.read Boolean.typ x) )

  module Challenge = Challenge.Make (Impl)
  module Digest = Digest.Make (Impl)
  module Scalar_challenge = SC.Make (Impl) (Inner_curve) (Challenge) (Endo.Dum)

  let product m f = List.reduce_exn (List.init m ~f) ~f:Field.( * )

  let absorb sponge ty t =
    absorb ~absorb_field:(Sponge.absorb sponge)
      ~g1_to_field_elements:Inner_curve.to_field_elements
      ~absorb_scalar:(Sponge.absorb sponge) ty t

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
                Other_field.Packed.Constant.(
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

  let equal_g g1 g2 =
    List.map2_exn ~f:Field.equal
      (Inner_curve.to_field_elements g1)
      (Inner_curve.to_field_elements g2)
    |> Boolean.all

  let combined_commitment ~xi (polys : _ Vector.t) =
    let (p0 :: ps) = polys in
    List.fold_left (Vector.to_list ps) ~init:p0 ~f:(fun acc p ->
        Inner_curve.(p + scale acc xi) )

  module One_hot_vector = One_hot_vector.Make (Impl)

  type 'a index' = 'a Abc.t Matrix_evals.t

  type 'a index = 'a Poly_comm.Without_degree_bound.t Abc.t Matrix_evals.t

  let seal x =
    match Field.to_constant x with
    | Some x ->
        Field.constant x
    | None ->
        let y = exists Field.typ ~compute:As_prover.(fun () -> read_var x) in
        Field.Assert.equal x y ; y

  let positions () (type a) : (a index' -> a) index' =
    let ( ^ ) (f : a index' -> a Abc.t) (g : a Abc.t -> a) : a index' -> a =
      Fn.compose g f
    in
    let abc f =
      let open Abc in
      {a= f ^ a; b= f ^ b; c= f ^ c}
    in
    let open Matrix_evals in
    {row= abc row; col= abc col; rc= abc rc; value= abc value}

  (* Mask out the given vector of indices with the given one-hot vector *)
  let choose_key : type n.
         n One_hot_vector.t
      -> (Inner_curve.t index, n) Vector.t
      -> (Boolean.var * Inner_curve.t) index =
    let open Tuple_lib in
    let map' ~f = Matrix_evals.map ~f:(Abc.map ~f) in
    let map2' ~f = Matrix_evals.map2 ~f:(Abc.map2 ~f) in
    let map2 ~f =
      Matrix_evals.map2
        ~f:
          (Abc.map2
             ~f:
               (Array.map2_exn ~f:(fun (b1, (x1, y1)) (b2, (x2, y2)) ->
                    (f b1 b2, (f x1 x2, f y1 y2)) )))
    in
    fun bs keys ->
      (* Probably a better way of doing this *)
      let max_lengths : int index' =
        map' (positions ()) ~f:(fun p ->
            Vector.reduce_exn
              (Vector.map keys ~f:(Fn.compose Array.length p))
              ~f:Int.max )
      in
      let padded =
        Vector.map keys ~f:(fun key ->
            map2' key max_lengths ~f:(fun c m ->
                Array.append
                  (Array.map c ~f:(fun g -> (Boolean.true_, g)))
                  (Array.create
                     ~len:(m - Array.length c)
                     (Boolean.false_, Inner_curve.one)) ) )
      in
      Vector.map2
        (bs :> (Boolean.var, n) Vector.t)
        padded
        ~f:(fun b key ->
          map' key
            ~f:
              (Array.map ~f:(fun (keep, g) ->
                   let open Field in
                   ( (Boolean.(keep && b) :> t)
                   , Double.map g ~f:(( * ) (b :> t)) ) )) )
      |> Vector.reduce_exn ~f:(map2 ~f:Field.( + ))
      |> map'
           ~f:
             (Array.map ~f:(fun (b, g) ->
                  (Boolean.Unsafe.of_cvar b, Double.map ~f:seal g) ))

  (* TODO: Can also do this at compile time *)
  let lagrange_precomputations =
    let of_domain =
      let module M = struct
        include Domain
        include Comparable.Make (Domain)
      end in
      Memo.of_comparable
        (module M)
        (fun d ->
          Array.map
            ~f:(fun x -> lazy (Inner_curve.Scaling_precomputation.create x))
            (Input_domain.lagrange_commitments d) )
    in
    fun ~input_size i ->
      let d = Domain.Pow_2_roots_of_unity (Int.ceil_log2 input_size) in
      Lazy.force (of_domain d).(i)

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

  module Split_commitments = struct
    module Curve_with_zero = struct
      type t = {point: Inner_curve.t; non_zero: Boolean.var}
    end

    let combine batch ~xi without_bound with_bound =
      let {Curve_with_zero.non_zero; point} =
        Pcs_batch.combine_split_commitments batch
          ~scale_and_add:(fun ~(acc : Curve_with_zero.t) ~xi (keep, p) ->
            (* match acc.non_zero, keep with
              | false, false -> acc
              | true, false -> acc
              | false, true -> { point= p; non_zero= true }
              | true, true -> { point= p + xi * acc; non_zero= true }
            *)
            let point =
              Inner_curve.(
                if_ keep
                  ~then_:
                    (if_ acc.non_zero
                       ~then_:(p + Scalar_challenge.endo acc.point xi)
                       ~else_:p)
                  ~else_:acc.point)
            in
            let non_zero = Boolean.(keep || acc.non_zero) in
            {Curve_with_zero.non_zero; point} )
          ~xi
          ~init:(fun (keep, p) -> {non_zero= keep; point= p})
          without_bound with_bound
      in
      Boolean.Assert.is_true non_zero ;
      point
  end

  let check_bulletproof ~pcs_batch ~sponge ~xi ~combined_inner_product
      ~
      (* Corresponds to y in figure 7 of WTS *)
      (* sum_i r^i sum_j xi^j f_j(beta_i) *)
      (advice : _ Types.Pairing_based.Openings.Bulletproof.Advice.t)
      ~polynomials:(without_degree_bound, with_degree_bound)
      ~openings_proof:({lr; delta; z_1; z_2; sg} :
                        ( Inner_curve.t
                        , Other_field.Packed.t )
                        Openings.Bulletproof.t) =
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
          Split_commitments.combine pcs_batch ~xi without_degree_bound
            with_degree_bound
        in
        let lr_prod, challenges = bullet_reduce sponge lr in
        let p_prime =
          combined_polynomial
          + scale u (Other_field.Packed.to_bits combined_inner_product)
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
          let scale t x = scale t (Other_field.Packed.to_bits x) in
          let b_u = scale u advice.b in
          let z_1_g_plus_b_u = scale (sg + b_u) z_1 in
          let z2_h =
            Inner_curve.multiscale_known
              [|(Other_field.Packed.to_bits z_2, Lazy.force h_precomp)|]
          in
          z_1_g_plus_b_u + z2_h
        in
        (`Success (equal_g lhs rhs), challenges) )

  module Opt =
    S.Bit_sponge.Make (struct
        type t = Boolean.var
      end)
      (struct
        type t = Field.t

        let to_bits = Field.choose_preimage_var ~length:Field.size_in_bits

        let high_entropy_bits = Wrap_main_inputs.high_entropy_bits
      end)
      (struct
        type t = Boolean.var * Field.t
      end)
      (Opt_sponge.Make (Impl))

  let absorb sponge ty t =
    Util.absorb ~absorb_field:(Opt.absorb sponge)
      ~g1_to_field_elements:(fun (b, (x, y)) -> [(b, x); (b, y)])
      ~absorb_scalar:(fun x -> Opt.absorb sponge (Boolean.true_, x))
      ty t

  module Pseudo = Pseudo.Make (Impl)

  let mask (type n) (lengths : (int, n) Vector.t) (choice : n One_hot_vector.t)
      : Boolean.var array =
    let max =
      Option.value_exn
        (List.max_elt ~compare:Int.compare (Vector.to_list lengths))
    in
    let length = Pseudo.choose (choice, lengths) ~f:Field.of_int in
    let (T max) = Nat.of_int max in
    Vector.to_array (ones_vector (module Impl) ~first_zero:length max)

  let mask_messages (type n) ~(lengths : (int, n) Vector.t Evals.t)
      (choice : n One_hot_vector.t) (m : _ Messages.t) =
    let f lens = Array.zip_exn (mask lens choice) in
    let gh lg lh ({Poly_comm.With_degree_bound.shifted; unshifted}, h) =
      ( { Poly_comm.With_degree_bound.shifted= (Boolean.true_, shifted)
        ; unshifted= f lg unshifted }
      , f lh h )
    in
    { Messages.w_hat= f lengths.w_hat m.w_hat
    ; z_hat_a= f lengths.z_hat_a m.z_hat_a
    ; z_hat_b= f lengths.z_hat_b m.z_hat_b
    ; gh_1= gh lengths.g_1 lengths.h_1 m.gh_1
    ; sigma_gh_2= Tuple2.map_snd m.sigma_gh_2 ~f:(gh lengths.g_2 lengths.h_2)
    ; sigma_gh_3= Tuple2.map_snd m.sigma_gh_3 ~f:(gh lengths.g_3 lengths.h_3)
    }

  let incrementally_verify_proof (type b)
      (module Max_branching : Nat.Add.Intf with type n = b) ~step_widths
      ~step_domains ~verification_key:(m : _ Abc.t Matrix_evals.t) ~xi ~sponge
      ~public_input ~(sg_old : (_, Max_branching.n) Vector.t)
      ~combined_inner_product ~advice
      ~(messages : _ Dlog_marlin_types.Messages.t) ~which_branch
      ~openings_proof =
    let T = Max_branching.eq in
    let messages =
      let open Vector in
      let lengths =
        let f field = map step_domains ~f:(Fn.compose Domain.size field) in
        Commitment_lengths.generic map ~h:(f Domains.h) ~k:(f Domains.k)
          ~max_degree:Common.Max_degree.step
      in
      mask_messages ~lengths which_branch messages
    in
    let sg_old =
      let actual_width =
        Pseudo.choose (which_branch, step_widths) ~f:Field.of_int
      in
      Vector.map2
        (ones_vector (module Impl) ~first_zero:actual_width Max_branching.n)
        sg_old
        ~f:(fun keep sg -> [|(keep, sg)|])
    in
    with_label __LOC__ (fun () ->
        let receive ty f =
          with_label __LOC__ (fun () ->
              let x = f messages in
              absorb sponge ty x ; x )
        in
        let sample () = Opt.squeeze sponge ~length:Challenge.length in
        let sample_scalar () : Scalar_challenge.t =
          Scalar_challenge (sample ())
        in
        let open Dlog_marlin_types.Messages in
        let x_hat =
          let input_size = Array.length public_input in
          Inner_curve.multiscale_known
            (Array.mapi public_input ~f:(fun i x ->
                 (x, lagrange_precomputations ~input_size i) ))
        in
        let without = Type.Without_degree_bound in
        let with_ = Type.With_degree_bound in
        absorb sponge PC (Boolean.true_, x_hat) ;
        print_g1 "x_hat" x_hat ;
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
        let sponge =
          S.Bit_sponge.map sponge
            ~f:(fun ({state; sponge_state; params} : _ Opt_sponge.t) ->
              match sponge_state with
              | Squeezed n ->
                  S.make ~state ~sponge_state:(Squeezed n) ~params
              | _ ->
                  assert false )
        in
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
            Vector.append sg_old
              [ [|(Boolean.true_, x_hat)|]
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
              (snd (Max_branching.add Nat.N19.n))
          in
          check_bulletproof
            ~pcs_batch:
              (Common.dlog_pcs_batch ~h_minus_1:() ~k_minus_1:()
                 (Max_branching.add Nat.N19.n))
            ~sponge:sponge_before_evaluations ~xi ~combined_inner_product
            ~advice ~openings_proof
            ~polynomials:(without_degree_bound, [g_1; g_2; g_3])
        in
        ( sponge_digest_before_evaluations
        , bulletproof_challenges
        , { Types.Dlog_based.Proof_state.Deferred_values.Marlin.sigma_2
          ; sigma_3
          ; alpha
          ; eta_a
          ; eta_b
          ; eta_c
          ; beta_1
          ; beta_2
          ; beta_3 } ) )

  module Split_evaluations = struct
    let combine_split_evaluations' s =
      Pcs_batch.combine_split_evaluations s
        ~mul:(fun (keep, x) (y : Field.t) -> (keep, Field.(y * x)))
        ~mul_and_add:(fun ~acc ~xi (keep, fx) ->
          Field.if_ keep ~then_:Field.(fx + (xi * acc)) ~else_:acc )
        ~init:(fun (_, fx) -> fx)
        ~shifted_pow:
          (Pseudo.Degree_bound.shifted_pow
             ~crs_max_degree:Common.Max_degree.wrap)
  end

  let mask_evals (type n) ~(lengths : (int, n) Vector.t Evals.t)
      (choice : n One_hot_vector.t) (e : Field.t array Evals.t) :
      (Boolean.var * Field.t) array Evals.t =
    Evals.map2 lengths e ~f:(fun lengths e ->
        Array.zip_exn (mask lengths choice) e )

  let combined_evaluation (type b b_plus_19) b_plus_19 ~xi ~evaluation_point
      ((without_degree_bound : (_, b_plus_19) Vector.t), with_degree_bound)
      ~h_minus_1 ~k_minus_1 =
    let open Field in
    Pcs_batch.combine_split_evaluations ~mul ~last:Array.last
      ~mul_and_add:(fun ~acc ~xi fx -> fx + (xi * acc))
      ~shifted_pow:
        (Pseudo.Degree_bound.shifted_pow ~crs_max_degree:Common.Max_degree.wrap)
      ~init:Fn.id ~evaluation_point ~xi
      (Common.dlog_pcs_batch b_plus_19 ~h_minus_1 ~k_minus_1)
      without_degree_bound with_degree_bound

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

  let b_poly = Field.(b_poly ~add ~mul ~inv)

  let pack_scalar_challenge (Pickles_types.Scalar_challenge.Scalar_challenge t)
      =
    Field.pack (Challenge.to_bits t)

  let actual_evaluation (e : Field.t array) (pt : Field.t) : Field.t =
    let pt_n =
      let max_degree_log2 = Int.ceil_log2 Common.Max_degree.wrap in
      let rec go acc i =
        if i = 0 then acc else go (Field.square acc) (i - 1)
      in
      go pt max_degree_log2
    in
    match List.rev (Array.to_list e) with
    | e :: es ->
        List.fold ~init:e es ~f:(fun acc y -> Field.(y + (pt_n * acc)))
    | [] ->
        failwith "empty list"

  (* This finalizes the "deferred values" coming from a previous proof over the same field.
   It 
   1. Checks that [xi] and [r] where sampled correctly. I.e., by absorbing all the
   evaluation openings and then squeezing.
   2. Checks that the "combined inner product" value used in the elliptic curve part of
   the opening proof was computed correctly, in terms of the evaluation openings and the
   evaluation points.
   3. Check that the "b" value was computed correctly.
   4. Perform the arithmetic checks from marlin. *)
  let finalize_other_proof (type b)
      (module Branching : Nat.Add.Intf with type n = b) ?actual_branching
      ~domain_h ~domain_k ~input_domain ~h_minus_1 ~k_minus_1 ~sponge
      ~(old_bulletproof_challenges : (_, b) Vector.t)
      ({xi; combined_inner_product; bulletproof_challenges; b; marlin} :
        _ Types.Pairing_based.Proof_state.Deferred_values.t)
      ((beta_1_evals, x_hat1), (beta_2_evals, x_hat2), (beta_3_evals, x_hat3))
      =
    let T = Branching.eq in
    let open Vector in
    (* You use the NEW bulletproof challenges to check b. Not the old ones. *)
    let open Field in
    let absorb_evals x_hat e =
      let xs, ys = Evals.to_vectors e in
      List.iter
        Vector.([|x_hat|] :: (to_list xs @ to_list ys))
        ~f:(Array.iter ~f:(Sponge.absorb sponge))
    in
    (* A lot of hashing. *)
    absorb_evals x_hat1 beta_1_evals ;
    absorb_evals x_hat2 beta_2_evals ;
    absorb_evals x_hat3 beta_3_evals ;
    let xi_actual = Sponge.squeeze sponge ~length:Challenge.length in
    let r_actual = Sponge.squeeze sponge ~length:Challenge.length in
    let xi_correct =
      (* Sample new sg challenge point here *)
      Field.equal (pack xi_actual) (pack_scalar_challenge xi)
    in
    let scalar = SC.to_field_checked (module Impl) ~endo:Endo.Dee.scalar in
    let marlin =
      Types.Pairing_based.Proof_state.Deferred_values.Marlin.map_challenges
        ~f:Field.pack ~scalar marlin
    in
    let xi = scalar xi in
    (* TODO: r actually does not need to be a scalar challenge. *)
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
          let a, b = Evals.to_vectors (e : Field.t array Evals.t) in
          let sg_evals =
            match actual_branching with
            | None ->
                Vector.map sg_olds ~f:(fun f -> [|f pt|])
            | Some branching ->
                let mask =
                  ones_vector
                    (module Impl)
                    ~first_zero:branching (Vector.length sg_olds)
                in
                Vector.map2 mask sg_olds ~f:(fun b f ->
                    [|Field.((b :> t) * f pt)|] )
          in
          let v = Vector.append sg_evals ([|x_hat|] :: a) (snd pi) in
          combined_evaluation pi ~xi ~evaluation_point:pt (v, b) ~h_minus_1
            ~k_minus_1
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
        ~input_domain ~domain_h ~domain_k ~x_hat_beta_1:x_hat1 marlin
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

  let map_challenges
      { Types.Pairing_based.Proof_state.Deferred_values.marlin
      ; combined_inner_product
      ; xi
      ; bulletproof_challenges
      ; b } ~f ~scalar =
    { Types.Pairing_based.Proof_state.Deferred_values.marlin=
        Types.Pairing_based.Proof_state.Deferred_values.Marlin.map_challenges
          marlin ~f ~scalar
    ; combined_inner_product
    ; bulletproof_challenges=
        Vector.map bulletproof_challenges
          ~f:(fun (r : _ Bulletproof_challenge.t) ->
            {r with prechallenge= scalar r.prechallenge} )
    ; xi= scalar xi
    ; b }

  (* TODO: No need to hash the entire bulletproof challenges. Could
   just hash the segment of the public input LDE corresponding to them
   that we compute when verifying the previous proof. That is a commitment
   to them. *)

  let hash_me_only (type n) (max_branching : n Nat.t)
      (t : (_, (_, n) Vector.t) Types.Dlog_based.Proof_state.Me_only.t) =
    let sponge = Sponge.create sponge_params in
    Array.iter ~f:(Sponge.absorb sponge)
      (Types.Dlog_based.Proof_state.Me_only.to_field_elements
         ~g1:Inner_curve.to_field_elements t) ;
    Sponge.squeeze_field sponge

  module Marlin = Types.Dlog_based.Proof_state.Deferred_values.Marlin

  (* Just for exhaustiveness over fields *)
  let iter2 ~fp ~chal ~scalar_chal
      { Marlin.sigma_2= sigma_2_0
      ; sigma_3= sigma_3_0
      ; alpha= alpha_0
      ; eta_a= eta_a_0
      ; eta_b= eta_b_0
      ; eta_c= eta_c_0
      ; beta_1= beta_1_0
      ; beta_2= beta_2_0
      ; beta_3= beta_3_0 }
      { Marlin.sigma_2= sigma_2_1
      ; sigma_3= sigma_3_1
      ; alpha= alpha_1
      ; eta_a= eta_a_1
      ; eta_b= eta_b_1
      ; eta_c= eta_c_1
      ; beta_1= beta_1_1
      ; beta_2= beta_2_1
      ; beta_3= beta_3_1 } =
    fp sigma_2_0 sigma_2_1 ;
    fp sigma_3_0 sigma_3_1 ;
    chal alpha_0 alpha_1 ;
    chal eta_a_0 eta_a_1 ;
    chal eta_b_0 eta_b_1 ;
    chal eta_c_0 eta_c_1 ;
    scalar_chal beta_1_0 beta_1_1 ;
    scalar_chal beta_2_0 beta_2_1 ;
    scalar_chal beta_3_0 beta_3_1

  let assert_eq_marlin
      (m1 :
        ( _
        , Field.t Pickles_types.Scalar_challenge.t
        , Field.t )
        Types.Dlog_based.Proof_state.Deferred_values.Marlin.t)
      (m2 :
        ( Boolean.var list
        , Scalar_challenge.t
        , Field.t )
        Types.Dlog_based.Proof_state.Deferred_values.Marlin.t) =
    iter2 m1 m2 ~fp:Field.Assert.equal
      ~chal:(fun c1 c2 -> Field.Assert.equal c1 (Field.project c2))
      ~scalar_chal:
        (fun (Scalar_challenge t1 : _ Pickles_types.Scalar_challenge.t)
             (Scalar_challenge t2 : Scalar_challenge.t) ->
        Field.Assert.equal t1 (Field.project t2) )
end
