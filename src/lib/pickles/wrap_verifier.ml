module type Inputs = Intf.Wrap_main_inputs.S

module S = Sponge
open Backend
open Core_kernel
open Util
module SC = Scalar_challenge
open Pickles_types
open Plonk_types
open Tuple_lib
open Import

let lookup_verification_enabled = false

(* given [chals], compute
   \prod_i (1 + chals.(i) * x^{2^{k - 1 - i}}) *)
let challenge_polynomial ~one ~add ~mul chals =
  let ( + ) = add and ( * ) = mul in
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
      prod (fun i -> one + (chals.(i) * pow_two_pows.(k - 1 - i))) )

let num_possible_domains = Nat.S Wrap_hack.Padded_length.n

let all_possible_domains =
  Memo.unit (fun () ->
      Vector.init num_possible_domains ~f:(fun proofs_verified ->
          (Common.wrap_domains ~proofs_verified).h ) )

module Make
    (Inputs : Inputs
                with type Impl.field = Wrap.Field.t
                 and type Impl.Bigint.t = Wrap.Bigint.R.t
                 and type Inner_curve.Constant.Scalar.t = Step.Field.t) =
struct
  open Inputs
  open Impl

  module Other_field = struct
    module Packed = struct
      module Constant = Other_field

      type t = Impls.Wrap.Other_field.t

      let typ = Impls.Wrap.Other_field.typ

      let to_bits_unsafe (x : t) = Wrap_main_inputs.Unsafe.unpack_unboolean x

      let absorb_shifted sponge (x : t Shifted_value.Type1.t) =
        match x with Shifted_value x -> Sponge.absorb sponge x
    end

    module With_top_bit0 = struct
      (* When the top bit is 0, there is no need to check that this is not
         equal to one of the forbidden values. The scaling is safe. *)
      module Constant = Other_field

      type t = Impls.Wrap.Other_field.t

      let typ = Impls.Wrap.Other_field.typ_unchecked

      let absorb_shifted sponge (x : t Shifted_value.Type1.t) =
        match x with Shifted_value x -> Sponge.absorb sponge x
    end
  end

  let num_possible_domains = num_possible_domains

  let all_possible_domains = all_possible_domains

  let print_g lab (x, y) =
    if debug then
      as_prover
        As_prover.(
          fun () ->
            printf
              !"%s: %{sexp:Backend.Wrap.Field.t}, %{sexp:Backend.Wrap.Field.t}\n\
                %!"
              lab (read_var x) (read_var y))

  let print_w lab gs =
    if debug then
      Array.iteri gs ~f:(fun i (fin, g) ->
          as_prover
            As_prover.(fun () -> printf "fin=%b %!" (read Boolean.typ fin)) ;
          ksprintf print_g "%s[%d]" lab i g )

  let print_chal lab x =
    if debug then
      as_prover
        As_prover.(
          fun () ->
            printf "in-snark %s:%!" lab ;
            Field.Constant.print
              (Field.Constant.project (List.map ~f:(read Boolean.typ) x)) ;
            printf "\n%!")

  let print_bool lab x =
    if debug then
      as_prover (fun () ->
          printf "%s: %b\n%!" lab (As_prover.read Boolean.typ x) )

  module Challenge = Challenge.Make (Impl)
  module Digest = Digest.Make (Impl)
  module Scalar_challenge =
    SC.Make (Impl) (Inner_curve) (Challenge) (Endo.Wrap_inner_curve)
  module Ops = Plonk_curve_ops.Make (Impl) (Inner_curve)

  let product m f = List.reduce_exn (List.init m ~f) ~f:Field.( * )

  let absorb sponge ty t =
    absorb
      ~mask_g1_opt:(fun () -> assert false)
      ~absorb_field:(Sponge.absorb sponge)
      ~g1_to_field_elements:Inner_curve.to_field_elements
      ~absorb_scalar:(Sponge.absorb sponge) ty t

  let scalar_to_field s =
    SC.to_field_checked (module Impl) s ~endo:Endo.Step_inner_curve.scalar

  let assert_n_bits ~n a =
    (* Scalar_challenge.to_field_checked has the side effect of
        checking that the input fits in n bits. *)
    ignore
      ( SC.to_field_checked
          (module Impl)
          (SC.SC.create a) ~endo:Endo.Step_inner_curve.scalar ~num_bits:n
        : Field.t )

  let lowest_128_bits ~constrain_low_bits x =
    let assert_128_bits = assert_n_bits ~n:128 in
    Util.lowest_128_bits ~constrain_low_bits ~assert_128_bits (module Impl) x

  let squeeze_challenge sponge : Field.t =
    lowest_128_bits (* I think you may not have to constrain these actually *)
      ~constrain_low_bits:true (Sponge.squeeze sponge)

  let squeeze_scalar sponge : Field.t SC.SC.t =
    (* No need to boolean constrain scalar challenges. *)
    SC.SC.create
      (lowest_128_bits ~constrain_low_bits:false (Sponge.squeeze sponge))

  let bullet_reduce sponge gammas =
    let absorb t = absorb sponge t in
    let prechallenges =
      Array.map gammas ~f:(fun gammas_i ->
          absorb (PC :: PC) gammas_i ;
          squeeze_scalar sponge )
    in
    let term_and_challenge (l, r) pre =
      let left_term = Scalar_challenge.endo_inv l pre in
      let right_term = Scalar_challenge.endo r pre in
      ( Ops.add_fast left_term right_term
      , { Bulletproof_challenge.prechallenge = pre } )
    in
    let terms, challenges =
      Array.map2_exn gammas prechallenges ~f:term_and_challenge |> Array.unzip
    in
    (Array.reduce_exn terms ~f:Ops.add_fast, challenges)

  let equal_g g1 g2 =
    List.map2_exn ~f:Field.equal
      (Inner_curve.to_field_elements g1)
      (Inner_curve.to_field_elements g2)
    |> Boolean.all

  module One_hot_vector = One_hot_vector.Make (Impl)

  type 'a index' = 'a Plonk_verification_key_evals.t

  type 'a index = 'a Plonk_verification_key_evals.t

  (* Mask out the given vector of indices with the given one-hot vector *)
  let choose_key :
      type n.
         n One_hot_vector.t
      -> (Inner_curve.t index', n) Vector.t
      -> Inner_curve.t index' =
    let open Tuple_lib in
    let map = Plonk_verification_key_evals.map in
    let map2 = Plonk_verification_key_evals.map2 in
    fun bs keys ->
      let open Field in
      Vector.map2
        (bs :> (Boolean.var, n) Vector.t)
        keys
        ~f:(fun b key -> map key ~f:(fun g -> Double.map g ~f:(( * ) (b :> t))))
      |> Vector.reduce_exn ~f:(map2 ~f:(Double.map2 ~f:( + )))
      |> map ~f:(fun g -> Double.map ~f:(Util.seal (module Impl)) g)

  (* TODO: Unify with the code in step_verifier *)
  let lagrange (type n)
      ~domain:
        ( (which_branch : n One_hot_vector.t)
        , (domains : (Domains.t, n) Vector.t) ) i =
    Vector.map domains ~f:(fun d ->
        let d =
          Precomputed.Lagrange_precomputations.index_of_domain_log2
            (Domain.log2_size d.h)
        in
        match Precomputed.Lagrange_precomputations.vesta.(d).(i) with
        | [| g |] ->
            let g = Inner_curve.Constant.of_affine g in
            Inner_curve.constant g
        | _ ->
            assert false )
    |> Vector.map2
         (which_branch :> (Boolean.var, n) Vector.t)
         ~f:(fun b (x, y) -> Field.((b :> t) * x, (b :> t) * y))
    |> Vector.reduce_exn ~f:(Double.map2 ~f:Field.( + ))

  let scaled_lagrange (type n) c
      ~domain:
        ( (which_branch : n One_hot_vector.t)
        , (domains : (Domains.t, n) Vector.t) ) i =
    Vector.map domains ~f:(fun d ->
        let d =
          Precomputed.Lagrange_precomputations.index_of_domain_log2
            (Domain.log2_size d.h)
        in
        match Precomputed.Lagrange_precomputations.vesta.(d).(i) with
        | [| g |] ->
            let g = Inner_curve.Constant.of_affine g in
            Inner_curve.Constant.scale g c |> Inner_curve.constant
        | _ ->
            assert false )
    |> Vector.map2
         (which_branch :> (Boolean.var, n) Vector.t)
         ~f:(fun b (x, y) -> Field.((b :> t) * x, (b :> t) * y))
    |> Vector.reduce_exn ~f:(Double.map2 ~f:Field.( + ))

  let lagrange_with_correction (type n) ~input_length
      ~domain:
        ( (which_branch : n One_hot_vector.t)
        , (domains : (Domains.t, n) Vector.t) ) i : Inner_curve.t Double.t =
    with_label __LOC__ (fun () ->
        let actual_shift =
          (* TODO: num_bits should maybe be input_length - 1. *)
          Ops.bits_per_chunk * Ops.chunks_needed ~num_bits:input_length
        in
        let rec pow2pow x i =
          if i = 0 then x else pow2pow Inner_curve.Constant.(x + x) (i - 1)
        in
        let base_and_correction (h : Domain.t) =
          let d =
            Precomputed.Lagrange_precomputations.index_of_domain_log2
              (Domain.log2_size h)
          in
          match Precomputed.Lagrange_precomputations.vesta.(d).(i) with
          | [| g |] ->
              let open Inner_curve.Constant in
              let g = of_affine g in
              ( Inner_curve.constant g
              , Inner_curve.constant (negate (pow2pow g actual_shift)) )
          | xs ->
              failwithf "expected commitment to have length 1. got %d"
                (Array.length xs) ()
        in
        match domains with
        | [] ->
            assert false
        | d :: ds ->
            if Vector.for_all ds ~f:(fun d' -> Domain.equal d.h d'.h) then
              base_and_correction d.h
            else
              Vector.map domains ~f:(fun (ds : Domains.t) ->
                  base_and_correction ds.h )
              |> Vector.map2
                   (which_branch :> (Boolean.var, n) Vector.t)
                   ~f:(fun b pr ->
                     Double.map pr ~f:(fun (x, y) ->
                         Field.((b :> t) * x, (b :> t) * y) ) )
              |> Vector.reduce_exn
                   ~f:(Double.map2 ~f:(Double.map2 ~f:Field.( + )))
              |> Double.map ~f:(Double.map ~f:(Util.seal (module Impl))) )

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
                   { b = Inner_curve.Params.b }
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
        |> unstage )
    in
    fun x -> Lazy.force f x

  module Split_commitments = struct
    module Point = struct
      type t =
        [ `Finite of Inner_curve.t
        | `Maybe_finite of Boolean.var * Inner_curve.t ]

      let finite : t -> Boolean.var = function
        | `Finite _ ->
            Boolean.true_
        | `Maybe_finite (b, _) ->
            b

      let add (p : t) (q : Inner_curve.t) =
        match p with
        | `Finite p ->
            Ops.add_fast p q
        | `Maybe_finite (finite, p) ->
            Inner_curve.if_ finite ~then_:(Ops.add_fast p q) ~else_:q

      let underlying = function `Finite p -> p | `Maybe_finite (_, p) -> p
    end

    module Curve_opt = struct
      type t = { point : Inner_curve.t; non_zero : Boolean.var }
    end

    let combine batch ~xi without_bound with_bound =
      let { Curve_opt.non_zero; point } =
        Pcs_batch.combine_split_commitments batch
          ~scale_and_add:(fun ~(acc : Curve_opt.t) ~xi (keep, (p : Point.t)) ->
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
                       ~then_:(Point.add p (Scalar_challenge.endo acc.point xi))
                       ~else_:
                         ((* In this branch, the accumulator was zero, so there is no harm in
                             putting the potentially junk underlying point here. *)
                          Point.underlying p ) )
                  ~else_:acc.point)
            in
            let non_zero = Boolean.(keep &&& Point.finite p ||| acc.non_zero) in
            { Curve_opt.non_zero; point } )
          ~xi
          ~init:(fun (keep, p) ->
            { non_zero = Boolean.(keep &&& Point.finite p)
            ; point = Point.underlying p
            } )
          without_bound with_bound
      in
      Boolean.Assert.is_true non_zero ;
      point
  end

  let scale_fast = Ops.scale_fast

  let check_bulletproof ~pcs_batch ~(sponge : Sponge.t)
      ~(xi : Scalar_challenge.t)
      ~(advice :
         Other_field.Packed.t Shifted_value.Type1.t
         Types.Step.Bulletproof.Advice.t )
      ~polynomials:(without_degree_bound, with_degree_bound)
      ~openings_proof:
        ({ lr; delta; z_1; z_2; challenge_polynomial_commitment } :
          ( Inner_curve.t
          , Other_field.Packed.t Shifted_value.Type1.t )
          Openings.Bulletproof.t ) =
    with_label __LOC__ (fun () ->
        Other_field.Packed.absorb_shifted sponge advice.combined_inner_product ;
        (* combined_inner_product should be equal to
           sum_i < t, r^i pows(beta_i) >
           = sum_i r^i < t, pows(beta_i) >

           That is checked later.
        *)
        let u =
          let t = Sponge.squeeze_field sponge in
          group_map t
        in
        let open Inner_curve in
        let combined_polynomial (* Corresponds to xi in figure 7 of WTS *) =
          Split_commitments.combine pcs_batch ~xi without_degree_bound
            with_degree_bound
        in
        let scale_fast =
          scale_fast ~num_bits:Other_field.Packed.Constant.size_in_bits
        in
        let lr_prod, challenges = bullet_reduce sponge lr in
        let p_prime =
          let uc = scale_fast u advice.combined_inner_product in
          combined_polynomial + uc
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
          let b_u = scale_fast u advice.b in
          let z_1_g_plus_b_u =
            scale_fast (challenge_polynomial_commitment + b_u) z_1
          in
          let z2_h =
            scale_fast (Inner_curve.constant (Lazy.force Generators.h)) z_2
          in
          z_1_g_plus_b_u + z2_h
        in
        (`Success (equal_g lhs rhs), challenges) )

  module Opt = struct
    include Opt_sponge.Make (Impl) (Wrap_main_inputs.Sponge.Permutation)

    let challenge (s : t) : Field.t =
      lowest_128_bits (squeeze s) ~constrain_low_bits:true

    (* No need to boolean constrain scalar challenges. *)
    let scalar_challenge (s : t) : Scalar_challenge.t =
      SC.SC.create (lowest_128_bits (squeeze s) ~constrain_low_bits:false)
  end

  (* TODO: This doesn't need to be an opt sponge *)
  let absorb sponge ty t =
    Util.absorb ~absorb_field:(Opt.absorb sponge)
      ~g1_to_field_elements:(fun (b, (x, y)) -> [ (b, x); (b, y) ])
      ~absorb_scalar:(fun x -> Opt.absorb sponge (Boolean.true_, x))
      ~mask_g1_opt:(fun ((finite : Boolean.var), (x, y)) ->
        (Boolean.true_, Field.((finite :> t) * x, (finite :> t) * y)) )
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

  module Plonk = Types.Wrap.Proof_state.Deferred_values.Plonk

  (* Just for exhaustiveness over fields *)
  let iter2 ~chal ~scalar_chal
      { Plonk.Minimal.alpha = alpha_0
      ; beta = beta_0
      ; gamma = gamma_0
      ; zeta = zeta_0
      }
      { Plonk.Minimal.alpha = alpha_1
      ; beta = beta_1
      ; gamma = gamma_1
      ; zeta = zeta_1
      } =
    if lookup_verification_enabled then failwith "TODO" else () ;
    chal beta_0 beta_1 ;
    chal gamma_0 gamma_1 ;
    scalar_chal alpha_0 alpha_1 ;
    scalar_chal zeta_0 zeta_1

  let assert_eq_marlin
      (m1 : (_, Field.t Import.Scalar_challenge.t) Plonk.Minimal.t)
      (m2 : (_, Scalar_challenge.t) Plonk.Minimal.t) =
    iter2 m1 m2
      ~chal:(fun c1 c2 -> Field.Assert.equal c1 c2)
      ~scalar_chal:(fun ({ inner = t1 } : _ Import.Scalar_challenge.t)
                        ({ inner = t2 } : Scalar_challenge.t) ->
        Field.Assert.equal t1 t2 )

  let incrementally_verify_proof (type b)
      (module Max_proofs_verified : Nat.Add.Intf with type n = b)
      ~actual_proofs_verified_mask ~step_domains
      ~verification_key:(m : _ Plonk_verification_key_evals.t) ~xi ~sponge
      ~(public_input :
         [ `Field of Field.t * Boolean.var | `Packed_bits of Field.t * int ]
         array ) ~(sg_old : (_, Max_proofs_verified.n) Vector.t) ~advice
      ~(messages : _ Messages.In_circuit.t) ~which_branch ~openings_proof
      ~(plonk : _ Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t) =
    let T = Max_proofs_verified.eq in
    let sg_old =
      with_label __LOC__ (fun () ->
          Vector.map2 actual_proofs_verified_mask sg_old ~f:(fun keep sg ->
              [| (keep, sg) |] ) )
    in
    with_label __LOC__ (fun () ->
        let sample () = Opt.challenge sponge in
        let sample_scalar () : Scalar_challenge.t =
          Opt.scalar_challenge sponge
        in
        let index_digest =
          with_label "absorb verifier index" (fun () ->
              let index_sponge = Sponge.create sponge_params in
              Array.iter
                (Types.index_to_field_elements
                   ~g:(fun (z : Inputs.Inner_curve.t) ->
                     List.to_array (Inner_curve.to_field_elements z) )
                   m )
                ~f:(fun x -> Sponge.absorb index_sponge x) ;
              Sponge.squeeze_field index_sponge )
        in
        let open Plonk_types.Messages in
        let without = Type.Without_degree_bound in
        let absorb_g gs =
          absorb sponge without (Array.map gs ~f:(fun g -> (Boolean.true_, g)))
        in
        absorb sponge Field (Boolean.true_, index_digest) ;
        Vector.iter ~f:(Array.iter ~f:(absorb sponge PC)) sg_old ;
        let x_hat =
          let domain = (which_branch, step_domains) in
          let public_input =
            Array.concat_map public_input ~f:(function
              | `Field (x, b) ->
                  [| `Field (x, Field.size_in_bits)
                   ; `Field ((b :> Field.t), 1)
                  |]
              | `Packed_bits (x, n) ->
                  [| `Field (x, n) |] )
          in
          let constant_part, non_constant_part =
            List.partition_map
              Array.(to_list (mapi public_input ~f:(fun i t -> (i, t))))
              ~f:(fun (i, t) ->
                match t with
                | `Field (Constant c, _) ->
                    First
                      ( if Field.Constant.(equal zero) c then None
                      else if Field.Constant.(equal one) c then
                        Some (lagrange ~domain i)
                      else
                        Some
                          (scaled_lagrange ~domain
                             (Inner_curve.Constant.Scalar.project
                                (Field.Constant.unpack c) )
                             i ) )
                | `Field x ->
                    Second (i, x) )
          in
          with_label __LOC__ (fun () ->
              let terms =
                List.map non_constant_part ~f:(fun (i, x) ->
                    match x with
                    | b, 1 ->
                        assert_ (Constraint.boolean (b :> Field.t)) ;
                        `Cond_add (Boolean.Unsafe.of_cvar b, lagrange ~domain i)
                    | x, n ->
                        `Add_with_correction
                          ( (x, n)
                          , lagrange_with_correction ~input_length:n ~domain i
                          ) )
              in
              let correction =
                with_label __LOC__ (fun () ->
                    List.reduce_exn
                      (List.filter_map terms ~f:(function
                        | `Cond_add _ ->
                            None
                        | `Add_with_correction (_, (_, corr)) ->
                            Some corr ) )
                      ~f:Ops.add_fast )
              in
              with_label __LOC__ (fun () ->
                  let init =
                    List.fold
                      (List.filter_map ~f:Fn.id constant_part)
                      ~init:correction ~f:Ops.add_fast
                  in
                  List.foldi terms ~init ~f:(fun i acc term ->
                      match term with
                      | `Cond_add (b, g) ->
                          with_label __LOC__ (fun () ->
                              Inner_curve.if_ b ~then_:(Ops.add_fast g acc)
                                ~else_:acc )
                      | `Add_with_correction ((x, num_bits), (g, _)) ->
                          Ops.add_fast acc
                            (Ops.scale_fast2'
                               (module Other_field.With_top_bit0)
                               g x ~num_bits ) ) ) )
          |> Inner_curve.negate
        in
        let x_hat =
          with_label "x_hat blinding" (fun () ->
              Ops.add_fast x_hat
                (Inner_curve.constant (Lazy.force Generators.h)) )
        in
        absorb sponge PC (Boolean.true_, x_hat) ;
        let w_comm = messages.w_comm in
        Vector.iter ~f:absorb_g w_comm ;
        let beta = sample () in
        let gamma = sample () in
        let z_comm = messages.z_comm in
        absorb_g z_comm ;
        let alpha = sample_scalar () in
        let t_comm :
            (Inputs.Impl.Field.t * Inputs.Impl.Field.t)
            Pickles_types__Plonk_types.Poly_comm.Without_degree_bound.t =
          messages.t_comm
        in
        absorb_g t_comm ;
        let zeta = sample_scalar () in
        (* At this point, we should use the previous "bulletproof_challenges" to
           compute to compute f(beta_1) outside the snark
           where f is the polynomial corresponding to sg_old
        *)
        let sponge =
          match sponge with
          | { state; sponge_state; params } -> (
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
        let sigma_comm_init, [ _ ] =
          Vector.split m.sigma_comm (snd (Permuts_minus_1.add Nat.N1.n))
        in
        let scale_fast =
          scale_fast ~num_bits:Other_field.Packed.Constant.size_in_bits
        in
        let ft_comm =
          with_label __LOC__ (fun () ->
              Common.ft_comm ~add:Ops.add_fast ~scale:scale_fast
                ~negate:Inner_curve.negate ~endoscale:Scalar_challenge.endo
                ~verification_key:m ~plonk ~alpha ~t_comm )
        in
        let bulletproof_challenges =
          (* This sponge needs to be initialized with (some derivative of)
             1. The polynomial commitments
             2. The combined inner product
             3. The challenge points.

             It should be sufficient to fork the sponge after squeezing beta_3 and then to absorb
             the combined inner product.
          *)
          let num_commitments_without_degree_bound = Nat.N26.n in
          let without_degree_bound =
            (* sg_old
               x_hat
               ft_comm
               z_comm
               generic selector
               poseidon selector
               w_comms
               all but last sigma_comm
            *)
            Vector.append sg_old
              ( [| x_hat |] :: [| ft_comm |] :: z_comm :: [| m.generic_comm |]
                :: [| m.psm_comm |]
                :: Vector.append w_comm
                     (Vector.map sigma_comm_init ~f:(fun g -> [| g |]))
                     (snd (Columns.add Permuts_minus_1.n))
              |> Vector.map ~f:(Array.map ~f:(fun g -> (Boolean.true_, g))) )
              (snd
                 (Max_proofs_verified.add num_commitments_without_degree_bound) )
          in
          check_bulletproof
            ~pcs_batch:
              (Common.dlog_pcs_batch
                 (Max_proofs_verified.add num_commitments_without_degree_bound) )
            ~sponge:sponge_before_evaluations ~xi ~advice ~openings_proof
            ~polynomials:
              ( Vector.map without_degree_bound
                  ~f:(Array.map ~f:(fun (keep, x) -> (keep, `Finite x)))
              , [] )
        in
        let joint_combiner =
          if lookup_verification_enabled then failwith "TODO" else None
        in
        assert_eq_marlin
          { alpha = plonk.alpha
          ; beta = plonk.beta
          ; gamma = plonk.gamma
          ; zeta = plonk.zeta
          ; joint_combiner
          }
          { alpha; beta; gamma; zeta; joint_combiner } ;
        (sponge_digest_before_evaluations, bulletproof_challenges) )

  let mask_evals (type n) ~(lengths : (int, n) Vector.t Evals.t)
      (choice : n One_hot_vector.t) (e : Field.t array Evals.t) :
      (Boolean.var * Field.t) array Evals.t =
    Evals.map2 lengths e ~f:(fun lengths e ->
        Array.zip_exn (mask lengths choice) e )

  let compute_challenges ~scalar chals =
    Vector.map chals ~f:(fun { Bulletproof_challenge.prechallenge } ->
        scalar prechallenge )

  let challenge_polynomial = Field.(challenge_polynomial ~add ~mul ~one)

  let pow2pow (pt : Field.t) (n : int) : Field.t =
    with_label __LOC__ (fun () ->
        let rec go acc i =
          if i = 0 then acc else go (Field.square acc) (i - 1)
        in
        go pt n )

  let actual_evaluation (e : Field.t array) ~(pt_to_n : Field.t) : Field.t =
    with_label __LOC__ (fun () ->
        match List.rev (Array.to_list e) with
        | e :: es ->
            List.fold ~init:e es ~f:(fun acc y ->
                let acc' =
                  exists Field.typ ~compute:(fun () ->
                      As_prover.read_var Field.(y + (pt_to_n * acc)) )
                in
                (* acc' = y + pt_n * acc *)
                let pt_n_acc = Field.(pt_to_n * acc) in
                let open
                  Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint in
                (* 0 = - acc' + y + pt_n_acc *)
                let open Field.Constant in
                assert_
                  { annotation = None
                  ; basic =
                      T
                        (Basic
                           { l = (one, y)
                           ; r = (one, pt_n_acc)
                           ; o = (negate one, acc')
                           ; m = zero
                           ; c = zero
                           } )
                  } ;
                acc' )
        | [] ->
            failwith "empty list" )

  let shift1 =
    Shifted_value.Type1.Shift.(
      map ~f:Field.constant (create (module Field.Constant)))

  let shift2 =
    Shifted_value.Type2.Shift.(
      map ~f:Field.constant (create (module Field.Constant)))

  let%test_unit "endo scalar" =
    SC.test (module Impl) ~endo:Endo.Step_inner_curve.scalar

  let map_plonk_to_field plonk =
    Types.Step.Proof_state.Deferred_values.Plonk.In_circuit.map_challenges
      ~f:(Util.seal (module Impl))
      ~scalar:scalar_to_field plonk
    |> Types.Step.Proof_state.Deferred_values.Plonk.In_circuit.map_fields
         ~f:(Shifted_value.Type2.map ~f:(Util.seal (module Impl)))

  module Plonk_checks = struct
    include Plonk_checks
    include Plonk_checks.Make (Shifted_value.Type2) (Plonk_checks.Scalars.Wrap)
  end

  let field_array_if b ~then_ ~else_ =
    Array.map2_exn then_ else_ ~f:(fun x1 x2 -> Field.if_ b ~then_:x1 ~else_:x2)

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
      (module Proofs_verified : Nat.Add.Intf with type n = b) ~domain ~sponge
      ~(old_bulletproof_challenges : (_, b) Vector.t)
      ({ xi; combined_inner_product; bulletproof_challenges; b; plonk } :
        ( _
        , _
        , _ Shifted_value.Type2.t
        , _
        , _ )
        Types.Step.Proof_state.Deferred_values.In_circuit.t )
      { Plonk_types.All_evals.In_circuit.ft_eval1; evals } =
    let T = Proofs_verified.eq in
    let open Vector in
    (* You use the NEW bulletproof challenges to check b. Not the old ones. *)
    let open Field in
    let plonk = map_plonk_to_field plonk in
    let zetaw = Field.mul domain#generator plonk.zeta in
    let sg_evals1, sg_evals2 =
      let sg_olds =
        Vector.map old_bulletproof_challenges ~f:(fun chals ->
            unstage (challenge_polynomial (Vector.to_array chals)) )
      in
      let sg_evals pt = Vector.map sg_olds ~f:(fun f -> f pt) in
      (sg_evals plonk.zeta, sg_evals zetaw)
    in
    let sponge_state =
      (* Absorb bulletproof challenges *)
      let challenge_digest =
        let sponge = Sponge.create sponge_params in
        Vector.iter old_bulletproof_challenges
          ~f:(Vector.iter ~f:(Sponge.absorb sponge)) ;
        Sponge.squeeze sponge
      in
      Sponge.absorb sponge challenge_digest ;
      Sponge.absorb sponge ft_eval1 ;
      Sponge.absorb sponge (fst evals.public_input) ;
      Sponge.absorb sponge (snd evals.public_input) ;
      let xs = Evals.In_circuit.to_absorption_sequence evals.evals in
      Plonk_types.Opt.Early_stop_sequence.fold field_array_if xs ~init:()
        ~f:(fun () (x1, x2) ->
          let absorb = Array.iter ~f:(Sponge.absorb sponge) in
          absorb x1 ; absorb x2 )
        ~finish:(fun () -> Array.copy sponge.state)
    in
    sponge.state <- sponge_state ;
    let xi_actual = squeeze_scalar sponge in
    let r_actual = squeeze_challenge sponge in
    let xi_correct =
      with_label __LOC__ (fun () ->
          let { SC.SC.inner = xi_actual } = xi_actual in
          let { SC.SC.inner = xi } = xi in
          (* Sample new sg challenge point here *)
          Field.equal xi_actual xi )
    in
    let xi = scalar_to_field xi in
    (* TODO: r actually does not need to be a scalar challenge. *)
    let r = scalar_to_field (SC.SC.create r_actual) in
    let plonk_minimal =
      Plonk.to_minimal plonk ~to_option:Plonk_types.Opt.to_option
    in
    let combined_evals =
      let n = Common.Max_degree.wrap_log2 in
      (* TODO: zeta_n is recomputed in [env] below *)
      let zeta_n = pow2pow plonk.zeta n in
      let zetaw_n = pow2pow zetaw n in
      Evals.In_circuit.map evals.evals ~f:(fun (x0, x1) ->
          ( actual_evaluation ~pt_to_n:zeta_n x0
          , actual_evaluation ~pt_to_n:zetaw_n x1 ) )
    in
    let env =
      Plonk_checks.scalars_env
        (module Field)
        ~srs_length_log2:Common.Max_degree.wrap_log2
        ~endo:(Impl.Field.constant Endo.Wrap_inner_curve.base)
        ~mds:sponge_params.mds
        ~field_of_hex:(fun s ->
          Kimchi_pasta.Pasta.Bigint256.of_hex_string s
          |> Kimchi_pasta.Pasta.Fq.of_bigint |> Field.constant )
        ~domain plonk_minimal combined_evals
    in
    let combined_inner_product_correct =
      let evals1, evals2 =
        All_evals.With_public_input.In_circuit.factor evals
      in
      with_label __LOC__ (fun () ->
          let ft_eval0 : Field.t =
            with_label __LOC__ (fun () ->
                Plonk_checks.ft_eval0
                  (module Field)
                  ~lookup_constant_term_part:None ~env ~domain plonk_minimal
                  combined_evals evals1.public_input )
          in
          (* sum_i r^i sum_j xi^j f_j(beta_i) *)
          let actual_combined_inner_product =
            let combine ~ft ~sg_evals x_hat
                (e : (Field.t array, _) Evals.In_circuit.t) =
              let a =
                Evals.In_circuit.to_list e
                |> List.map ~f:(function
                     | None ->
                         [||]
                     | Some a ->
                         Array.map a ~f:(fun x -> Plonk_types.Opt.Some x)
                     | Maybe (b, a) ->
                         Array.map a ~f:(fun x -> Plonk_types.Opt.Maybe (b, x)) )
              in
              let sg_evals =
                Vector.map sg_evals ~f:(fun x -> [| Plonk_types.Opt.Some x |])
                |> Vector.to_list
                (* TODO: This was the code before the wrap hack was put in
                   match actual_proofs_verified with
                   | None ->
                       Vector.map sg_olds ~f:(fun f -> [| f pt |])
                   | Some proofs_verified ->
                       let mask =
                         ones_vector
                           (module Impl)
                           ~first_zero:proofs_verified (Vector.length sg_olds)
                       in
                       with_label __LOC__ (fun () ->
                           Vector.map2 mask sg_olds ~f:(fun b f ->
                               [| Field.((b :> t) * f pt) |] ) ) *)
              in
              let v =
                List.append sg_evals ([| Some x_hat |] :: [| Some ft |] :: a)
              in
              Common.combined_evaluation (module Impl) ~xi v
            in
            combine ~ft:ft_eval0 ~sg_evals:sg_evals1 evals1.public_input
              evals1.evals
            + r
              * combine ~ft:ft_eval1 ~sg_evals:sg_evals2 evals2.public_input
                  evals2.evals
          in
          with_label __LOC__ (fun () ->
              equal
                (Shifted_value.Type2.to_field
                   (module Field)
                   ~shift:shift2 combined_inner_product )
                actual_combined_inner_product ) )
    in
    let bulletproof_challenges =
      with_label __LOC__ (fun () ->
          compute_challenges ~scalar:scalar_to_field bulletproof_challenges )
    in
    let b_correct =
      with_label __LOC__ (fun () ->
          let challenge_poly =
            unstage
              (challenge_polynomial (Vector.to_array bulletproof_challenges))
          in
          let b_actual =
            challenge_poly plonk.zeta + (r * challenge_poly zetaw)
          in
          equal
            (Shifted_value.Type2.to_field (module Field) ~shift:shift2 b)
            b_actual )
    in
    let plonk_checks_passed =
      with_label __LOC__ (fun () ->
          Plonk_checks.checked
            (module Impl)
            ~env ~shift:shift2 plonk combined_evals )
    in
    print_bool "xi_correct" xi_correct ;
    print_bool "combined_inner_product_correct" combined_inner_product_correct ;
    print_bool "plonk_checks_passed" plonk_checks_passed ;
    print_bool "b_correct" b_correct ;
    ( Boolean.all
        [ xi_correct
        ; b_correct
        ; combined_inner_product_correct
        ; plonk_checks_passed
        ]
    , bulletproof_challenges )

  let map_challenges
      { Types.Step.Proof_state.Deferred_values.plonk
      ; combined_inner_product
      ; xi
      ; bulletproof_challenges
      ; b
      } ~f ~scalar =
    { Types.Step.Proof_state.Deferred_values.plonk =
        Types.Step.Proof_state.Deferred_values.Plonk.In_circuit.map_challenges
          plonk ~f ~scalar
    ; combined_inner_product
    ; bulletproof_challenges =
        Vector.map bulletproof_challenges
          ~f:(fun (r : _ Bulletproof_challenge.t) ->
            { Bulletproof_challenge.prechallenge = scalar r.prechallenge } )
    ; xi = scalar xi
    ; b
    }
end
