module S = Sponge
open Core_kernel
open Util
module SC = Scalar_challenge
open Pickles_types
open Plonk_types
open Tuple_lib
open Import

(* G is for Generic. This module is just to protect {!val:challenge_polynomial}
   below from being hidden by the included functor application at the end of
   the module, so that we can re-export it in the end. *)
module G = struct
  (* given [chals], compute
     \prod_i (1 + chals.(i) * x^{2^{k - 1 - i}}) *)
  let challenge_polynomial (type a)
      (module M : Pickles_types.Shifted_value.Field_intf with type t = a) chals
      : (a -> a) Staged.t =
    stage (fun pt ->
        let k = Array.length chals in
        let pow_two_pows =
          let res = Array.init k ~f:(fun _ -> pt) in
          for i = 1 to k - 1 do
            let y = res.(i - 1) in
            res.(i) <- M.(y * y)
          done ;
          res
        in
        let prod f =
          let r = ref (f 0) in
          for i = 1 to k - 1 do
            r := M.(f i * !r)
          done ;
          !r
        in
        prod (fun i ->
            let idx = k - 1 - i in
            M.(one + (chals.(i) * pow_two_pows.(idx))) ) )

  let num_possible_domains = Nat.S Wrap_hack.Padded_length.n

  let all_possible_domains =
    Memo.unit (fun () ->
        Vector.init num_possible_domains ~f:(fun proofs_verified ->
            (Common.wrap_domains ~proofs_verified).h ) )
end

module Make
    (Inputs : Intf.Wrap_main_inputs.S
                with type Impl.field = Backend.Tock.Field.t
                 and type Impl.Bigint.t = Backend.Tock.Bigint.t
                 and type Inner_curve.Constant.Scalar.t = Backend.Tick.Field.t) =
struct
  open Inputs
  open Impl

  module Other_field = struct
    module Packed = struct
      module Constant = Other_field

      type t = Impls.Wrap.Other_field.t

      let typ = Impls.Wrap.Other_field.typ

      let _to_bits_unsafe (x : t) = Wrap_main_inputs.Unsafe.unpack_unboolean x

      let absorb_shifted sponge (x : t Shifted_value.Type1.t) =
        match x with Shifted_value x -> Sponge.absorb sponge x
    end

    module With_top_bit0 = struct
      (* When the top bit is 0, there is no need to check that this is not
         equal to one of the forbidden values. The scaling is safe. *)
      module Constant = Other_field

      type t = Impls.Wrap.Other_field.t

      let typ = Impls.Wrap.Other_field.typ_unchecked

      let _absorb_shifted sponge (x : t Pickles_types.Shifted_value.Type1.t) =
        match x with Shifted_value x -> Sponge.absorb sponge x
    end
  end

  let num_possible_domains = G.num_possible_domains

  let all_possible_domains = G.all_possible_domains

  let print_g lab (x, y) =
    if debug then
      as_prover
        As_prover.(
          fun () ->
            printf
              !"%s: %{sexp:Backend.Tock.Field.t}, %{sexp:Backend.Tock.Field.t}\n\
                %!"
              lab (read_var x) (read_var y))

  let _print_w lab gs =
    if Import.debug then
      Array.iteri gs ~f:(fun i (fin, g) ->
          as_prover
            As_prover.(fun () -> printf "fin=%b %!" (read Boolean.typ fin)) ;
          ksprintf print_g "%s[%d]" lab i g )

  let _print_chal lab x =
    if Import.debug then
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

  let _product m f =
    Core_kernel.List.reduce_exn (Core_kernel.List.init m ~f) ~f:Field.( * )

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
          (Import.Scalar_challenge.create a)
          ~endo:Endo.Step_inner_curve.scalar ~num_bits:n
        : Field.t )

  let lowest_128_bits ~constrain_low_bits x =
    let assert_128_bits = assert_n_bits ~n:128 in
    Util.lowest_128_bits ~constrain_low_bits ~assert_128_bits (module Impl) x

  let squeeze_challenge sponge : Field.t =
    lowest_128_bits (* I think you may not have to constrain these actually *)
      ~constrain_low_bits:true (Sponge.squeeze sponge)

  let squeeze_scalar sponge : Field.t Import.Scalar_challenge.t =
    (* No need to boolean constrain scalar challenges. *)
    Import.Scalar_challenge.create
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
      (Ops.add_fast left_term right_term, Bulletproof_challenge.unpack pre)
    in
    let terms, challenges =
      Array.map2_exn gammas prechallenges ~f:term_and_challenge |> Array.unzip
    in

    (Array.reduce_exn terms ~f:(Ops.add_fast ?check_finite:None), challenges)

  let equal_g g1 g2 =
    List.map2_exn ~f:Field.equal
      (Inner_curve.to_field_elements g1)
      (Inner_curve.to_field_elements g2)
    |> Boolean.all

  module One_hot_vector = One_hot_vector.Make (Impl)

  type ('a, 'a_opt) index' = ('a, 'a_opt) Plonk_verification_key_evals.Step.t

  (* Mask out the given vector of indices with the given one-hot vector *)
  let choose_key :
      type n.
         n One_hot_vector.t
      -> ( (Inner_curve.t array, (Inner_curve.t array, Boolean.var) Opt.t) index'
         , n )
         Vector.t
      -> (Inner_curve.t array, (Inner_curve.t array, Boolean.var) Opt.t) index'
      =
    let open Tuple_lib in
    fun bs keys ->
      let open Field in
      Vector.map2
        (bs :> (Boolean.var, n) Vector.t)
        keys
        ~f:(fun b key ->
          Plonk_verification_key_evals.Step.map key
            ~f:(Array.map ~f:(fun g -> Double.map g ~f:(( * ) (b :> t))))
            ~f_opt:(function
              (* Here, we split the 3 variants into 3 separate accumulators. This
                 allows us to only compute the 'maybe' flag when we need to, and
                 allows us to fall back to the basically-free `Nothing` when a
                 feature is entirely unused, or to the less expensive `Just` if
                 it is used for every circuit.
                 In particular, it is important that we generate exactly
                 `Nothing` when none of the optional gates are used, otherwise
                 we will change the serialization of the protocol circuits.
              *)
              | Opt.Nothing ->
                  ([], [], [ b ])
              | Opt.Maybe (b_x, x) ->
                  ([], [ (b, b_x, x) ], [])
              | Opt.Just x ->
                  ([ (b, x) ], [], []) ) )
      |> Vector.reduce_exn
           ~f:
             (Plonk_verification_key_evals.Step.map2
                ~f:(Array.map2_exn ~f:(Double.map2 ~f:( + )))
                ~f_opt:(fun (yes_1, maybe_1, no_1) (yes_2, maybe_2, no_2) ->
                  (yes_1 @ yes_2, maybe_1 @ maybe_2, no_1 @ no_2) ) )
      |> Plonk_verification_key_evals.Step.map ~f:Fn.id ~f_opt:(function
           | [], [], _nones ->
               (* We only have `Nothing`s, so we can emit exactly `Nothing`
                  without further computation.
               *)
               Opt.Nothing
           | justs, [], [] ->
               (* Special case: we don't need to compute the 'maybe' bool
                  because we know statically that all entries are `Just`.
               *)
               let sum =
                 justs
                 |> List.map ~f:(fun ((b : Boolean.var), g) ->
                        Array.map g ~f:(Double.map ~f:(( * ) (b :> t))) )
                 |> List.reduce_exn
                      ~f:(Array.map2_exn ~f:(Double.map2 ~f:( + )))
               in
               Opt.just sum
           | justs, maybes, nones ->
               let is_none =
                 List.reduce nones
                   ~f:(fun (b1 : Boolean.var) (b2 : Boolean.var) ->
                     Boolean.Unsafe.of_cvar Field.(add (b1 :> t) (b2 :> t)) )
               in
               let none_sum =
                 let num_chunks = (* TODO *) 1 in
                 Option.map is_none ~f:(fun (b : Boolean.var) ->
                     Array.init num_chunks ~f:(fun _ ->
                         Double.map Inner_curve.one ~f:(( * ) (b :> t)) ) )
               in
               let just_is_yes, just_sum =
                 justs
                 |> List.map ~f:(fun ((b : Boolean.var), g) ->
                        (b, Array.map g ~f:(Double.map ~f:(( * ) (b :> t)))) )
                 |> List.reduce
                      ~f:(fun ((b1 : Boolean.var), g1) ((b2 : Boolean.var), g2)
                         ->
                        ( Boolean.Unsafe.of_cvar Field.(add (b1 :> t) (b2 :> t))
                        , Array.map2_exn ~f:(Double.map2 ~f:( + )) g1 g2 ) )
                 |> fun x -> (Option.map ~f:fst x, Option.map ~f:snd x)
               in
               let maybe_is_yes, maybe_sum =
                 maybes
                 |> List.map
                      ~f:(fun ((b : Boolean.var), (b_g : Boolean.var), g) ->
                        ( Boolean.Unsafe.of_cvar Field.(mul (b :> t) (b_g :> t))
                        , Array.map g ~f:(Double.map ~f:(( * ) (b :> t))) ) )
                 |> List.reduce
                      ~f:(fun ((b1 : Boolean.var), g1) ((b2 : Boolean.var), g2)
                         ->
                        ( Boolean.Unsafe.of_cvar Field.(add (b1 :> t) (b2 :> t))
                        , Array.map2_exn ~f:(Double.map2 ~f:( + )) g1 g2 ) )
                 |> fun x -> (Option.map ~f:fst x, Option.map ~f:snd x)
               in
               let is_yes =
                 [| just_is_yes; maybe_is_yes |]
                 |> Array.filter_map ~f:Fn.id
                 |> Array.reduce_exn
                      ~f:(fun (b1 : Boolean.var) (b2 : Boolean.var) ->
                        Boolean.Unsafe.of_cvar ((b1 :> t) + (b2 :> t)) )
               in
               let sum =
                 [| none_sum; maybe_sum; just_sum |]
                 |> Array.filter_map ~f:Fn.id
                 |> Array.reduce_exn
                      ~f:(Array.map2_exn ~f:(Double.map2 ~f:( + )))
               in
               Opt.Maybe (is_yes, sum) )
      |> Plonk_verification_key_evals.Step.map
           ~f:(fun g -> Array.map ~f:(Double.map ~f:(Util.seal (module Impl))) g)
           ~f_opt:(function
             | Opt.Nothing ->
                 Opt.Nothing
             | Opt.Maybe (b, x) ->
                 Opt.Maybe
                   ( Boolean.Unsafe.of_cvar (Util.seal (module Impl) (b :> t))
                   , Array.map ~f:(Double.map ~f:(Util.seal (module Impl))) x )
             | Opt.Just x ->
                 Opt.Just
                   (Array.map ~f:(Double.map ~f:(Util.seal (module Impl))) x) )

  (* TODO: Unify with the code in step_verifier *)
  let lagrange (type n)
      ~domain:
        ( (which_branch : n One_hot_vector.t)
        , (domains : (Domains.t, n) Vector.t) ) srs i =
    Vector.map domains ~f:(fun d ->
        let d = Int.pow 2 (Domain.log2_size d.h) in
        let chunks =
          (Kimchi_bindings.Protocol.SRS.Fp.lagrange_commitment srs d i)
            .unshifted
        in
        Array.map chunks ~f:(function
          | Finite g ->
              let g = Inner_curve.Constant.of_affine g in
              Inner_curve.constant g
          | Infinity ->
              (* Point at infinity should be impossible in the SRS *)
              assert false ) )
    |> Vector.map2
         (which_branch :> (Boolean.var, n) Vector.t)
         ~f:(fun b pts ->
           Array.map pts ~f:(fun (x, y) -> Field.((b :> t) * x, (b :> t) * y))
           )
    |> Vector.reduce_exn ~f:(Array.map2_exn ~f:(Double.map2 ~f:Field.( + )))

  let scaled_lagrange (type n) c
      ~domain:
        ( (which_branch : n One_hot_vector.t)
        , (domains : (Domains.t, n) Vector.t) ) srs i =
    Vector.map domains ~f:(fun d ->
        let d = Int.pow 2 (Domain.log2_size d.h) in
        let chunks =
          (Kimchi_bindings.Protocol.SRS.Fp.lagrange_commitment srs d i)
            .unshifted
        in
        Array.map chunks ~f:(function
          | Finite g ->
              let g = Inner_curve.Constant.of_affine g in
              Inner_curve.Constant.scale g c |> Inner_curve.constant
          | Infinity ->
              (* Point at infinity should be impossible in the SRS *)
              assert false ) )
    |> Vector.map2
         (which_branch :> (Boolean.var, n) Vector.t)
         ~f:(fun b pts ->
           Array.map pts ~f:(fun (x, y) -> Field.((b :> t) * x, (b :> t) * y))
           )
    |> Vector.reduce_exn ~f:(Array.map2_exn ~f:(Double.map2 ~f:Field.( + )))

  let lagrange_with_correction (type n) ~input_length
      ~domain:
        ( (which_branch : n One_hot_vector.t)
        , (domains : (Domains.t, n) Vector.t) ) srs i :
      Inner_curve.t Double.t array =
    with_label __LOC__ (fun () ->
        let actual_shift =
          (* TODO: num_bits should maybe be input_length - 1. *)
          Ops.bits_per_chunk * Ops.chunks_needed ~num_bits:input_length
        in
        let rec pow2pow x i =
          if i = 0 then x else pow2pow Inner_curve.Constant.(x + x) (i - 1)
        in
        let base_and_correction (h : Domain.t) =
          let d = Int.pow 2 (Domain.log2_size h) in
          let chunks =
            (Kimchi_bindings.Protocol.SRS.Fp.lagrange_commitment srs d i)
              .unshifted
          in
          Array.map chunks ~f:(function
            | Finite g ->
                let open Inner_curve.Constant in
                let g = of_affine g in
                ( Inner_curve.constant g
                , Inner_curve.constant (negate (pow2pow g actual_shift)) )
            | Infinity ->
                (* Point at infinity should be impossible in the SRS *)
                assert false )
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
                     Array.map pr
                       ~f:
                         (Double.map ~f:(fun (x, y) ->
                              Field.((b :> t) * x, (b :> t) * y) ) ) )
              |> Vector.reduce_exn
                   ~f:
                     (Array.map2_exn
                        ~f:(Double.map2 ~f:(Double.map2 ~f:Field.( + ))) )
              |> Array.map
                   ~f:(Double.map ~f:(Double.map ~f:(Util.seal (module Impl)))) )

  let _h_precomp =
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

      let _finite : t -> Boolean.var = function
        | `Finite _ ->
            Boolean.true_
        | `Maybe_finite (b, _) ->
            b

      let assert_finite : t -> unit = function
        | `Finite _ ->
            ()
        | `Maybe_finite _ ->
            failwith "Not finite"

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
      let reduce_point p =
        let point = ref (Point.underlying p.(Array.length p - 1)) in
        for i = Array.length p - 2 downto 0 do
          point := Point.add p.(i) (Scalar_challenge.endo !point xi)
        done ;
        !point
      in
      let { Curve_opt.non_zero; point } =
        Pcs_batch.combine_split_commitments batch
          ~reduce_with_degree_bound:(fun _ -> assert false)
          ~reduce_without_degree_bound:(fun x -> [ x ])
          ~scale_and_add:(fun ~(acc : Curve_opt.t) ~xi
                              (p : (Point.t array, Boolean.var) Opt.t) ->
            (* match acc.non_zero, keep with
               | false, false -> acc
               | true, false -> acc
               | false, true -> { point= p; non_zero= true }
               | true, true -> { point= p + xi * acc; non_zero= true }
            *)
            let point keep p =
              let base_point =
                let p = p.(Array.length p - 1) in
                Inner_curve.(
                  if_ acc.non_zero
                    ~then_:(Point.add p (Scalar_challenge.endo acc.point xi))
                    ~else_:
                      ((* In this branch, the accumulator was zero, so there is no harm in
                          putting the potentially junk underlying point here. *)
                       Point.underlying p ))
              in
              let point = ref base_point in
              for i = Array.length p - 2 downto 0 do
                point := Point.add p.(i) (Scalar_challenge.endo !point xi)
              done ;
              let point =
                Inner_curve.(if_ keep ~then_:!point ~else_:acc.point)
              in
              Array.iter ~f:Point.assert_finite p ;
              let non_zero = Boolean.(keep &&& true_ ||| acc.non_zero) in
              { Curve_opt.non_zero; point }
            in
            match p with
            | Opt.Nothing ->
                acc
            | Opt.Maybe (keep, p) ->
                point keep p
            | Opt.Just p ->
                point Boolean.true_ p )
          ~xi
          ~init:(function
            | Opt.Nothing ->
                None
            | Opt.Maybe (keep, p) ->
                Array.iter ~f:Point.assert_finite p ;
                Some
                  { non_zero = Boolean.(keep &&& true_)
                  ; point = reduce_point p
                  }
            | Opt.Just p ->
                Array.iter ~f:Point.assert_finite p ;
                Some
                  { non_zero = Boolean.(true_ &&& true_)
                  ; point = reduce_point p
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
      Import.Scalar_challenge.create
        (lowest_128_bits (squeeze s) ~constrain_low_bits:false)
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
      { Plonk.Minimal.In_circuit.alpha = alpha_0
      ; beta = beta_0
      ; gamma = gamma_0
      ; zeta = zeta_0
      ; joint_combiner = joint_combiner_0
      ; feature_flags = _
      }
      { Plonk.Minimal.In_circuit.alpha = alpha_1
      ; beta = beta_1
      ; gamma = gamma_1
      ; zeta = zeta_1
      ; joint_combiner = joint_combiner_1
      ; feature_flags = _
      } =
    with_label __LOC__ (fun () ->
        match[@warning "-4"] (joint_combiner_0, joint_combiner_1) with
        | Nothing, Nothing ->
            ()
        | Maybe (b0, j0), Maybe (b1, j1) ->
            Boolean.Assert.(b0 = b1) ;
            let (Typ { var_to_fields; _ }) = Scalar_challenge.typ in
            Array.iter2_exn ~f:Field.Assert.equal
              (fst @@ var_to_fields j0)
              (fst @@ var_to_fields j1)
        | Just j0, Just j1 ->
            let (Typ { var_to_fields; _ }) = Scalar_challenge.typ in
            Array.iter2_exn ~f:Field.Assert.equal
              (fst @@ var_to_fields j0)
              (fst @@ var_to_fields j1)
        | ( ((Pickles_types.Opt.Just _ | Maybe _ | Nothing) as j0)
          , ((Pickles_types.Opt.Just _ | Maybe _ | Nothing) as j1) ) ->
            let sexp_of t =
              Sexp.to_string
              @@ Types.Opt.sexp_of_t
                   (fun _ -> Sexp.Atom "")
                   (fun _ -> Sexp.Atom "")
                   t
            in
            failwithf
              "incompatible optional states for joint_combiners: %s vs %s"
              (sexp_of j0) (sexp_of j1) () ) ;
    with_label __LOC__ (fun () -> chal beta_0 beta_1) ;
    with_label __LOC__ (fun () -> chal gamma_0 gamma_1) ;
    with_label __LOC__ (fun () -> scalar_chal alpha_0 alpha_1) ;
    with_label __LOC__ (fun () -> scalar_chal zeta_0 zeta_1)

  let assert_eq_plonk
      (m1 : (_, Field.t Import.Scalar_challenge.t, _) Plonk.Minimal.In_circuit.t)
      (m2 : (_, Scalar_challenge.t, _) Plonk.Minimal.In_circuit.t) =
    iter2 m1 m2
      ~chal:(fun c1 c2 -> Field.Assert.equal c1 c2)
      ~scalar_chal:(fun ({ inner = t1 } : _ Import.Scalar_challenge.t)
                        ({ inner = t2 } : Scalar_challenge.t) ->
        Field.Assert.equal t1 t2 )

  let index_to_field_elements ~g (m : _ Plonk_verification_key_evals.Step.t) =
    let { Plonk_verification_key_evals.Step.sigma_comm
        ; coefficients_comm
        ; generic_comm
        ; psm_comm
        ; complete_add_comm
        ; mul_comm
        ; emul_comm
        ; endomul_scalar_comm
        ; range_check0_comm
        ; range_check1_comm
        ; foreign_field_mul_comm
        ; foreign_field_add_comm
        ; xor_comm
        ; rot_comm
        ; lookup_table_comm
        ; lookup_table_ids
        ; runtime_tables_selector
        ; lookup_selector_xor
        ; lookup_selector_lookup
        ; lookup_selector_range_check
        ; lookup_selector_ffmul
        } =
      m
    in
    let open Pickles_types in
    let g_opt = Opt.map ~f:g in
    List.map
      ( Vector.to_list sigma_comm
      @ Vector.to_list coefficients_comm
      @ [ generic_comm
        ; psm_comm
        ; complete_add_comm
        ; mul_comm
        ; emul_comm
        ; endomul_scalar_comm
        ] )
      ~f:(fun x -> Opt.just (g x))
    @ [ g_opt range_check0_comm
      ; g_opt range_check1_comm
      ; g_opt foreign_field_mul_comm
      ; g_opt foreign_field_add_comm
      ; g_opt xor_comm
      ; g_opt rot_comm
      ]
    @ List.map ~f:g_opt (Vector.to_list lookup_table_comm)
    @ [ g_opt lookup_table_ids
      ; g_opt runtime_tables_selector
      ; g_opt lookup_selector_xor
      ; g_opt lookup_selector_lookup
      ; g_opt lookup_selector_range_check
      ; g_opt lookup_selector_ffmul
      ]

  (** Simulate an [Opt_sponge.t] locally in a block, but without running the
      expensive optional logic that is otherwise required.

      Invariant: This requires that the sponge 'state' (i.e. the state after
      absorbing or squeezing) is consistent between the initial state and the
      final state when using the sponge.
  *)
  let simulate_optional_sponge_with_alignment (sponge : Sponge.t) ~f = function
    | Pickles_types.Opt.Nothing ->
        Pickles_types.Opt.Nothing
    | Pickles_types.Opt.Maybe (b, x) ->
        (* Cache the sponge state before *)
        let sponge_state_before = sponge.sponge_state in
        let state_before = Array.copy sponge.state in
        (* Use the sponge *)
        let res = f sponge x in
        (* Check that the sponge ends in a compatible state. *)
        ( match (sponge_state_before, sponge.sponge_state) with
        | Absorbed x, Absorbed y ->
            [%test_eq: int] x y
        | Squeezed x, Squeezed y ->
            [%test_eq: int] x y
        | Absorbed _, Squeezed _ ->
            [%test_eq: string] "absorbed" "squeezed"
        | Squeezed _, Absorbed _ ->
            [%test_eq: string] "squeezed" "absorbed" ) ;
        let state =
          Array.map2_exn sponge.state state_before ~f:(fun then_ else_ ->
              Field.if_ b ~then_ ~else_ )
        in
        sponge.state <- state ;
        Pickles_types.Opt.Maybe (b, res)
    | Pickles_types.Opt.Just x ->
        Pickles_types.Opt.Just (f sponge x)

  let incrementally_verify_proof (type b)
      (module Max_proofs_verified : Nat.Add.Intf with type n = b)
      ~actual_proofs_verified_mask ~step_domains ~srs
      ~verification_key:(m : (_ array, _) Plonk_verification_key_evals.Step.t)
      ~xi ~sponge
      ~(public_input :
         [ `Field of Field.t * Boolean.var | `Packed_bits of Field.t * int ]
         array ) ~(sg_old : (_, Max_proofs_verified.n) Vector.t) ~advice
      ~(messages : _ Messages.In_circuit.t) ~which_branch ~openings_proof
      ~(plonk : _ Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t) =
    let T = Max_proofs_verified.eq in
    let sg_old =
      with_label __LOC__ (fun () ->
          Vector.map2 actual_proofs_verified_mask sg_old ~f:(fun keep sg ->
              (keep, sg) ) )
    in
    with_label __LOC__ (fun () ->
        let sample () = Opt.challenge sponge in
        let sample_scalar () : Scalar_challenge.t =
          Opt.scalar_challenge sponge
        in
        let index_digest =
          with_label "absorb verifier index" (fun () ->
              let index_sponge = Sponge.create sponge_params in
              List.iter
                (index_to_field_elements
                   ~g:
                     (Array.concat_map ~f:(fun (z : Inputs.Inner_curve.t) ->
                          List.to_array (Inner_curve.to_field_elements z) ) )
                   m )
                ~f:(fun x ->
                  let (_ : (unit, _) Pickles_types.Opt.t) =
                    simulate_optional_sponge_with_alignment index_sponge x
                      ~f:(fun sponge x ->
                        Array.iter ~f:(Sponge.absorb sponge) x )
                  in
                  () ) ;
              Sponge.squeeze_field index_sponge )
        in
        let without = Type.Without_degree_bound in
        let absorb_g gs =
          absorb sponge without (Array.map gs ~f:(fun g -> (Boolean.true_, g)))
        in
        absorb sponge Field (Boolean.true_, index_digest) ;
        Vector.iter ~f:(absorb sponge PC) sg_old ;
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
                match[@warning "-4"] t with
                | `Field (Constant c, _) ->
                    First
                      ( if Field.Constant.(equal zero) c then None
                      else if Field.Constant.(equal one) c then
                        Some (lagrange ~domain srs i)
                      else
                        Some
                          (scaled_lagrange ~domain
                             (Inner_curve.Constant.Scalar.project
                                (Field.Constant.unpack c) )
                             srs i ) )
                | `Field x ->
                    Second (i, x) )
          in
          with_label __LOC__ (fun () ->
              let terms =
                List.map non_constant_part ~f:(fun (i, x) ->
                    match x with
                    | b, 1 ->
                        assert_ (Constraint.boolean (b :> Field.t)) ;
                        `Cond_add
                          (Boolean.Unsafe.of_cvar b, lagrange ~domain srs i)
                    | x, n ->
                        `Add_with_correction
                          ( (x, n)
                          , lagrange_with_correction ~input_length:n ~domain srs
                              i ) )
              in
              let correction =
                with_label __LOC__ (fun () ->
                    List.reduce_exn
                      (List.filter_map terms ~f:(function
                        | `Cond_add _ ->
                            None
                        | `Add_with_correction (_, chunks) ->
                            Some (Array.map ~f:snd chunks) ) )
                      ~f:(Array.map2_exn ~f:(Ops.add_fast ?check_finite:None)) )
              in
              with_label __LOC__ (fun () ->
                  let init =
                    List.fold
                      (List.filter_map ~f:Fn.id constant_part)
                      ~init:correction
                      ~f:(Array.map2_exn ~f:(Ops.add_fast ?check_finite:None))
                  in
                  List.fold terms ~init ~f:(fun acc term ->
                      match term with
                      | `Cond_add (b, g) ->
                          with_label __LOC__ (fun () ->
                              Array.map2_exn acc g ~f:(fun acc g ->
                                  Inner_curve.if_ b ~then_:(Ops.add_fast g acc)
                                    ~else_:acc ) )
                      | `Add_with_correction ((x, num_bits), chunks) ->
                          Array.map2_exn acc chunks ~f:(fun acc (g, _) ->
                              Ops.add_fast acc
                                (Ops.scale_fast2'
                                   (module Other_field.With_top_bit0)
                                   g x ~num_bits ) ) ) ) )
          |> Array.map ~f:Inner_curve.negate
        in
        let x_hat =
          with_label "x_hat blinding" (fun () ->
              Array.map x_hat ~f:(fun x_hat ->
                  Ops.add_fast x_hat
                    (Inner_curve.constant (Lazy.force Generators.h)) ) )
        in
        Array.iter x_hat ~f:(fun x_hat ->
            absorb sponge PC (Boolean.true_, x_hat) ) ;
        let w_comm = messages.w_comm in
        Vector.iter ~f:absorb_g w_comm ;
        let runtime_comm =
          match messages.lookup with
          | Nothing
          | Maybe (_, { runtime = Nothing; _ })
          | Just { runtime = Nothing; _ } ->
              Pickles_types.Opt.Nothing
          | Maybe (b_lookup, { runtime = Maybe (b_runtime, runtime); _ }) ->
              let b = Boolean.( &&& ) b_lookup b_runtime in
              Pickles_types.Opt.Maybe (b, runtime)
          | Maybe (b, { runtime = Just runtime; _ })
          | Just { runtime = Maybe (b, runtime); _ } ->
              Pickles_types.Opt.Maybe (b, runtime)
          | Just { runtime = Just runtime; _ } ->
              Pickles_types.Opt.Just runtime
        in
        let absorb_runtime_tables () =
          match runtime_comm with
          | Nothing ->
              ()
          | Maybe (b, runtime) ->
              let z = Array.map runtime ~f:(fun z -> (b, z)) in
              absorb sponge Without_degree_bound z
          | Just runtime ->
              let z = Array.map runtime ~f:(fun z -> (Boolean.true_, z)) in
              absorb sponge Without_degree_bound z
        in
        absorb_runtime_tables () ;
        let joint_combiner =
          let compute_joint_combiner (l : _ Messages.Lookup.In_circuit.t) =
            let absorb_sorted_1 sponge =
              let (first :: _) = l.sorted in
              let z = Array.map first ~f:(fun z -> (Boolean.true_, z)) in
              absorb sponge Without_degree_bound z
            in
            let absorb_sorted_2_to_4 () =
              let (_ :: rest) = l.sorted in
              Vector.iter rest ~f:(fun z ->
                  let z = Array.map z ~f:(fun z -> (Boolean.true_, z)) in
                  absorb sponge Without_degree_bound z )
            in
            let absorb_sorted_5 () =
              match l.sorted_5th_column with
              | Nothing ->
                  ()
              | Maybe (b, z) ->
                  let z = Array.map z ~f:(fun z -> (b, z)) in
                  absorb sponge Without_degree_bound z
              | Just z ->
                  let z = Array.map z ~f:(fun z -> (Boolean.true_, z)) in
                  absorb sponge Without_degree_bound z
            in
            match[@warning "-4"]
              (m.lookup_table_comm, m.runtime_tables_selector)
            with
            | _ :: Just _ :: _, _ | _, Just _ ->
                let joint_combiner = sample_scalar () in
                absorb_sorted_1 sponge ;
                absorb_sorted_2_to_4 () ;
                absorb_sorted_5 () ;
                joint_combiner
            | _ :: Nothing :: _, Nothing ->
                absorb_sorted_1 sponge ;
                absorb_sorted_2_to_4 () ;
                absorb_sorted_5 () ;
                { inner = Field.zero }
            | _ :: Maybe (b1, _) :: _, Maybe (b2, _) ->
                let b = Boolean.(b1 ||| b2) in
                let sponge2 = Opt.copy sponge in
                let joint_combiner_if_true =
                  let joint_combiner = sample_scalar () in
                  absorb_sorted_1 sponge ; joint_combiner
                in
                let joint_combiner_if_false : Scalar_challenge.t =
                  absorb_sorted_1 sponge2 ; { inner = Field.zero }
                in
                Opt.recombine b ~original_sponge:sponge2 sponge ;
                absorb_sorted_2_to_4 () ;
                absorb_sorted_5 () ;
                { inner =
                    Field.if_ b ~then_:joint_combiner_if_true.inner
                      ~else_:joint_combiner_if_false.inner
                }
            | _ :: Maybe (b, _) :: _, _ | _, Maybe (b, _) ->
                let sponge2 = Opt.copy sponge in
                let joint_combiner_if_true =
                  let joint_combiner = sample_scalar () in
                  absorb_sorted_1 sponge ; joint_combiner
                in
                let joint_combiner_if_false : Scalar_challenge.t =
                  absorb_sorted_1 sponge2 ; { inner = Field.zero }
                in
                Opt.recombine b ~original_sponge:sponge2 sponge ;
                absorb_sorted_2_to_4 () ;
                absorb_sorted_5 () ;
                { inner =
                    Field.if_ b ~then_:joint_combiner_if_true.inner
                      ~else_:joint_combiner_if_false.inner
                }
          in
          match messages.lookup with
          | Nothing ->
              Types.Opt.Nothing
          | Maybe (b, l) ->
              Opt.consume_all_pending sponge ;
              let sponge2 = Opt.copy sponge in
              let joint_combiner = compute_joint_combiner l in
              Opt.consume_all_pending sponge ;
              Opt.recombine b ~original_sponge:sponge2 sponge ;
              (* We explicitly set this, because when we squeeze for [beta], we
                 there will be no pending values *but* we don't want to add a
                 dedicated permutation.
              *)
              sponge.needs_final_permute_if_empty <- false ;
              Types.Opt.Maybe (b, joint_combiner)
          | Just l ->
              Opt.consume_all_pending sponge ;
              Types.Opt.just (compute_joint_combiner l)
        in
        let lookup_table_comm =
          let compute_lookup_table_comm (l : _ Messages.Lookup.In_circuit.t)
              joint_combiner =
            let (first_column :: second_column :: rest) = m.lookup_table_comm in
            let second_column_with_runtime =
              match (second_column, l.runtime) with
              | Types.Opt.Nothing, comm | comm, Types.Opt.Nothing ->
                  comm
              | ( Types.Opt.Maybe (has_second_column, second_column)
                , Types.Opt.Maybe (has_runtime, runtime) ) ->
                  let second_with_runtime =
                    let sum =
                      Array.map2_exn ~f:Inner_curve.( + ) second_column runtime
                    in
                    Array.map2_exn second_column sum
                      ~f:(fun second_column sum ->
                        Inner_curve.if_ has_runtime ~then_:sum
                          ~else_:second_column )
                  in
                  let res =
                    Array.map2_exn second_with_runtime runtime
                      ~f:(fun second_with_runtime runtime ->
                        Inner_curve.if_ has_second_column
                          ~then_:second_with_runtime ~else_:runtime )
                  in
                  let b = Boolean.(has_second_column ||| has_runtime) in
                  Types.Opt.maybe b res
              | ( Types.Opt.Maybe (has_second_column, second_column)
                , Types.Opt.Just runtime ) ->
                  let res =
                    let sum =
                      Array.map2_exn ~f:Inner_curve.( + ) second_column runtime
                    in
                    Array.map2_exn runtime sum ~f:(fun runtime sum ->
                        Inner_curve.if_ has_second_column ~then_:sum
                          ~else_:runtime )
                  in
                  Types.Opt.just res
              | ( Types.Opt.Just second_column
                , Types.Opt.Maybe (has_runtime, runtime) ) ->
                  let res =
                    let sum =
                      Array.map2_exn ~f:Inner_curve.( + ) second_column runtime
                    in
                    Array.map2_exn second_column sum
                      ~f:(fun second_column sum ->
                        Inner_curve.if_ has_runtime ~then_:sum
                          ~else_:second_column )
                  in
                  Types.Opt.just res
              | Types.Opt.Just second_column, Types.Opt.Just runtime ->
                  Types.Opt.just
                    (Array.map2_exn ~f:Inner_curve.( + ) second_column runtime)
            in
            let rest_rev =
              Vector.rev (first_column :: second_column_with_runtime :: rest)
            in
            Vector.fold ~init:m.lookup_table_ids rest_rev ~f:(fun acc comm ->
                match acc with
                | Types.Opt.Nothing ->
                    comm
                | Types.Opt.Maybe (has_acc, acc) -> (
                    match comm with
                    | Types.Opt.Nothing ->
                        Types.Opt.maybe has_acc acc
                    | Types.Opt.Maybe (has_comm, comm) ->
                        let scaled_acc =
                          Array.map acc ~f:(fun acc ->
                              Scalar_challenge.endo acc joint_combiner )
                        in
                        let sum =
                          Array.map2_exn ~f:Inner_curve.( + ) scaled_acc comm
                        in
                        let acc_with_comm =
                          Array.map2_exn sum comm ~f:(fun sum comm ->
                              Inner_curve.if_ has_acc ~then_:sum ~else_:comm )
                        in
                        let res =
                          Array.map2_exn acc acc_with_comm
                            ~f:(fun acc acc_with_comm ->
                              Inner_curve.if_ has_comm ~then_:acc_with_comm
                                ~else_:acc )
                        in
                        let b = Boolean.(has_acc ||| has_comm) in
                        Types.Opt.maybe b res
                    | Types.Opt.Just comm ->
                        let scaled_acc =
                          Array.map acc ~f:(fun acc ->
                              Scalar_challenge.endo acc joint_combiner )
                        in
                        let sum =
                          Array.map2_exn ~f:Inner_curve.( + ) scaled_acc comm
                        in
                        let res =
                          Array.map2_exn sum comm ~f:(fun sum comm ->
                              Inner_curve.if_ has_acc ~then_:sum ~else_:comm )
                        in
                        Types.Opt.just res )
                | Types.Opt.Just acc -> (
                    match comm with
                    | Types.Opt.Nothing ->
                        Types.Opt.just acc
                    | Types.Opt.Maybe (has_comm, comm) ->
                        let scaled_acc =
                          Array.map acc ~f:(fun acc ->
                              Scalar_challenge.endo acc joint_combiner )
                        in
                        let sum =
                          Array.map2_exn ~f:Inner_curve.( + ) scaled_acc comm
                        in
                        let res =
                          Array.map2_exn sum acc ~f:(fun sum acc ->
                              Inner_curve.if_ has_comm ~then_:sum ~else_:acc )
                        in
                        Types.Opt.just res
                    | Types.Opt.Just comm ->
                        let scaled_acc =
                          Array.map acc ~f:(fun acc ->
                              Scalar_challenge.endo acc joint_combiner )
                        in
                        Types.Opt.Just
                          (Array.map2_exn ~f:Inner_curve.( + ) scaled_acc comm)
                    ) )
          in
          match (messages.lookup, joint_combiner) with
          | Types.Opt.Nothing, Types.Opt.Nothing ->
              Types.Opt.Nothing
          | ( Types.Opt.Maybe (b_l, l)
            , Types.Opt.Maybe (_b_joint_combiner, joint_combiner) ) -> (
              (* NB: b_l = _b_joint_combiner by construction *)
              match compute_lookup_table_comm l joint_combiner with
              | Types.Opt.Nothing ->
                  Types.Opt.Nothing
              | Types.Opt.Maybe (b_lookup_table_comm, lookup_table_comm) ->
                  Types.Opt.Maybe
                    (Boolean.(b_l &&& b_lookup_table_comm), lookup_table_comm)
              | Types.Opt.Just lookup_table_comm ->
                  Types.Opt.Maybe (b_l, lookup_table_comm) )
          | Types.Opt.Just l, Types.Opt.Just joint_combiner ->
              compute_lookup_table_comm l joint_combiner
          | ( (Types.Opt.Nothing | Maybe _ | Just _)
            , (Types.Opt.Nothing | Maybe _ | Just _) ) ->
              assert false
        in
        let lookup_sorted =
          let lookup_sorted_minus_1 =
            Nat.to_int Plonk_types.Lookup_sorted_minus_1.n
          in
          Vector.init Plonk_types.Lookup_sorted.n ~f:(fun i ->
              match messages.lookup with
              | Types.Opt.Nothing ->
                  Types.Opt.Nothing
              | Types.Opt.Maybe (b, l) ->
                  if i = lookup_sorted_minus_1 then l.sorted_5th_column
                  else
                    Types.Opt.Maybe (b, Option.value_exn (Vector.nth l.sorted i))
              | Types.Opt.Just l ->
                  if i = lookup_sorted_minus_1 then l.sorted_5th_column
                  else Types.Opt.Just (Option.value_exn (Vector.nth l.sorted i)) )
        in
        let beta = sample () in
        let gamma = sample () in
        let () =
          match messages.lookup with
          | Nothing ->
              ()
          | Maybe (b, l) ->
              let aggreg = Array.map l.aggreg ~f:(fun z -> (b, z)) in
              absorb sponge Without_degree_bound aggreg
          | Just l ->
              let aggreg =
                Array.map l.aggreg ~f:(fun z -> (Boolean.true_, z))
              in
              absorb sponge Without_degree_bound aggreg
        in
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
          | { state
            ; sponge_state = Squeezed n
            ; params
            ; needs_final_permute_if_empty = _
            } ->
              S.make ~state ~sponge_state:(Squeezed n) ~params
          | { sponge_state = Absorbing _; _ } ->
              assert false
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
              Common.ft_comm
                ~add:(Ops.add_fast ?check_finite:None)
                ~scale:scale_fast ~negate:Inner_curve.negate
                ~endoscale:(Scalar_challenge.endo ?num_bits:None)
                ~verification_key:
                  (Plonk_verification_key_evals.Step.forget_optional_commitments
                     m )
                ~plonk ~alpha ~t_comm )
        in
        let bulletproof_challenges =
          (* This sponge needs to be initialized with (some derivative of)
             1. The polynomial commitments
             2. The combined inner product
             3. The challenge points.

             It should be sufficient to fork the sponge after squeezing beta_3 and then to absorb
             the combined inner product.
          *)
          let len_1, len_1_add = Plonk_types.(Columns.add Permuts_minus_1.n) in
          let len_2, len_2_add = Plonk_types.(Columns.add len_1) in
          let _len_3, len_3_add = Nat.N9.add len_2 in
          let _len_4, len_4_add = Nat.N6.add Plonk_types.Lookup_sorted.n in
          let len_5, len_5_add =
            (* NB: Using explicit 11 because we can't get add on len_4 *)
            Nat.N11.add Nat.N8.n
          in
          let len_6, len_6_add = Nat.N45.add len_5 in
          let num_commitments_without_degree_bound = len_6 in
          let without_degree_bound =
            let append_chain len second first =
              Vector.append first second len
            in
            (* sg_old
               x_hat
               ft_comm
               z_comm
               generic selector
               poseidon selector
               w_comms
               all but last sigma_comm
            *)
            Vector.map sg_old ~f:(fun (keep, p) ->
                Pickles_types.Opt.Maybe (keep, [| p |]) )
            |> append_chain
                 (snd (Max_proofs_verified.add len_6))
                 ( [ x_hat
                   ; [| ft_comm |]
                   ; z_comm
                   ; m.generic_comm
                   ; m.psm_comm
                   ; m.complete_add_comm
                   ; m.mul_comm
                   ; m.emul_comm
                   ; m.endomul_scalar_comm
                   ]
                 |> append_chain len_3_add
                      (Vector.append w_comm
                         (Vector.append m.coefficients_comm sigma_comm_init
                            len_1_add )
                         len_2_add )
                 |> Vector.map ~f:Pickles_types.Opt.just
                 |> append_chain len_6_add
                      ( [ m.range_check0_comm
                        ; m.range_check1_comm
                        ; m.foreign_field_add_comm
                        ; m.foreign_field_mul_comm
                        ; m.xor_comm
                        ; m.rot_comm
                        ]
                      |> append_chain len_4_add lookup_sorted
                      |> append_chain len_5_add
                           [ Pickles_types.Opt.map messages.lookup ~f:(fun l ->
                                 l.aggreg )
                           ; lookup_table_comm
                           ; runtime_comm
                           ; m.runtime_tables_selector
                           ; m.lookup_selector_xor
                           ; m.lookup_selector_lookup
                           ; m.lookup_selector_range_check
                           ; m.lookup_selector_ffmul
                           ] ) )
          in
          check_bulletproof
            ~pcs_batch:
              (Common.dlog_pcs_batch
                 (Max_proofs_verified.add num_commitments_without_degree_bound) )
            ~sponge:sponge_before_evaluations ~xi ~advice ~openings_proof
            ~polynomials:
              ( Vector.map without_degree_bound
                  ~f:
                    (Pickles_types.Opt.map
                       ~f:(Array.map ~f:(fun x -> `Finite x)) )
              , [] )
        in
        assert_eq_plonk
          { alpha = plonk.alpha
          ; beta = plonk.beta
          ; gamma = plonk.gamma
          ; zeta = plonk.zeta
          ; joint_combiner = plonk.joint_combiner
          ; feature_flags = plonk.feature_flags
          }
          { alpha
          ; beta
          ; gamma
          ; zeta
          ; joint_combiner
          ; feature_flags = plonk.feature_flags
          } ;
        (sponge_digest_before_evaluations, bulletproof_challenges) )

  let _mask_evals (type n)
      ~(lengths :
         (int, n) Pickles_types.Vector.t Pickles_types.Plonk_types.Evals.t )
      (choice : n One_hot_vector.t)
      (e : Field.t array Pickles_types.Plonk_types.Evals.t) :
      (Boolean.var * Field.t) array Pickles_types.Plonk_types.Evals.t =
    Pickles_types.Plonk_types.Evals.map2 lengths e ~f:(fun lengths e ->
        Array.zip_exn (mask lengths choice) e )

  let compute_challenges ~scalar chals =
    Vector.map chals ~f:(fun prechallenge ->
        scalar @@ Bulletproof_challenge.pack prechallenge )

  let challenge_polynomial = G.challenge_polynomial (module Field)

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

  let _shift1 =
    Pickles_types.Shifted_value.Type1.Shift.(
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
    include Plonk_checks.Make (Shifted_value.Type2) (Plonk_checks.Scalars.Tock)
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
  let finalize_other_proof (type b)
      (module Proofs_verified : Nat.Add.Intf with type n = b) ~domain ~sponge
      ~(old_bulletproof_challenges : (_, b) Vector.t)
      ({ xi; combined_inner_product; bulletproof_challenges; b; plonk } :
        ( _
        , _
        , _ Shifted_value.Type2.t
        , _ )
        Types.Step.Proof_state.Deferred_values.In_circuit.t )
      { Plonk_types.All_evals.In_circuit.ft_eval1; evals } =
    let module Plonk = Types.Step.Proof_state.Deferred_values.Plonk in
    let T = Proofs_verified.eq in
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
      Array.iter ~f:(Sponge.absorb sponge) (fst evals.public_input) ;
      Array.iter ~f:(Sponge.absorb sponge) (snd evals.public_input) ;
      let xs = Evals.In_circuit.to_absorption_sequence evals.evals in
      (* This is a hacky, but much more efficient, version of the opt sponge.
         This uses the assumption that the sponge 'absorption state' will align
         after each optional absorption, letting us skip the expensive tracking
         that this would otherwise require.
         To future-proof this, we assert that the states are indeed compatible.
      *)
      List.iter xs ~f:(fun opt ->
          let absorb = Array.iter ~f:(fun x -> Sponge.absorb sponge x) in
          match opt with
          | Nothing ->
              ()
          | Just (x1, x2) ->
              absorb x1 ; absorb x2
          | Maybe (b, (x1, x2)) ->
              (* Cache the sponge state before *)
              let sponge_state_before = sponge.sponge_state in
              let state_before = Array.copy sponge.state in
              (* Absorb the points *)
              absorb x1 ;
              absorb x2 ;
              (* Check that the sponge ends in a compatible state. *)
              ( match (sponge_state_before, sponge.sponge_state) with
              | Absorbed x, Absorbed y ->
                  [%test_eq: int] x y
              | Squeezed x, Squeezed y ->
                  [%test_eq: int] x y
              | Absorbed _, Squeezed _ ->
                  [%test_eq: string] "absorbed" "squeezed"
              | Squeezed _, Absorbed _ ->
                  [%test_eq: string] "squeezed" "absorbed" ) ;
              let state =
                Array.map2_exn sponge.state state_before ~f:(fun then_ else_ ->
                    Field.if_ b ~then_ ~else_ )
              in
              sponge.state <- state ) ;
      Array.copy sponge.state
    in
    sponge.state <- sponge_state ;
    let xi_actual = squeeze_scalar sponge in
    let r_actual = squeeze_challenge sponge in
    let xi_correct =
      with_label __LOC__ (fun () ->
          let { Import.Scalar_challenge.inner = xi_actual } = xi_actual in
          let { Import.Scalar_challenge.inner = xi } = xi in
          (* Sample new sg challenge point here *)
          Field.equal xi_actual xi )
    in
    let xi = scalar_to_field xi in
    (* TODO: r actually does not need to be a scalar challenge. *)
    let r = scalar_to_field (Import.Scalar_challenge.create r_actual) in
    let plonk_minimal =
      plonk |> Plonk.to_minimal
      |> Plonk.Minimal.to_wrap
           ~feature_flags:Features.(map ~f:Boolean.var_of_value none_bool)
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
      let module Env_bool = struct
        include Boolean

        type t = Boolean.var
      end in
      let module Env_field = struct
        include Field

        type bool = Env_bool.t

        let if_ (b : bool) ~then_ ~else_ =
          match Impl.Field.to_constant (b :> t) with
          | Some x ->
              (* We have a constant, only compute the branch we care about. *)
              if Impl.Field.Constant.(equal one) x then then_ () else else_ ()
          | None ->
              if_ b ~then_:(then_ ()) ~else_:(else_ ())
      end in
      Plonk_checks.scalars_env
        (module Env_bool)
        (module Env_field)
        ~srs_length_log2:Common.Max_degree.wrap_log2 ~zk_rows:3
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
                  ~env ~domain plonk_minimal combined_evals evals1.public_input )
          in
          (* sum_i r^i sum_j xi^j f_j(beta_i) *)
          let actual_combined_inner_product =
            let combine ~ft ~sg_evals x_hat
                (e : (Field.t array, _) Evals.In_circuit.t) =
              let a =
                Evals.In_circuit.to_list e
                |> List.map ~f:(function
                     | Nothing ->
                         [||]
                     | Just a ->
                         Array.map a ~f:Pickles_types.Opt.just
                     | Maybe (b, a) ->
                         Array.map a ~f:(Pickles_types.Opt.maybe b) )
              in
              let sg_evals =
                Vector.map sg_evals ~f:(fun x -> [| Pickles_types.Opt.just x |])
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
                List.append sg_evals
                  ( Array.map ~f:Pickles_types.Opt.just x_hat
                  :: [| Pickles_types.Opt.just ft |]
                  :: a )
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
          (* This proof is a wrap proof; no need to consider features. *)
          Plonk_checks.checked
            (module Impl)
            ~env ~shift:shift2
            (Composition_types.Step.Proof_state.Deferred_values.Plonk.In_circuit
             .to_wrap ~opt_none:Pickles_types.Opt.nothing ~false_:Boolean.false_
               plonk )
            combined_evals )
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

  let _map_challenges
      { Import.Types.Step.Proof_state.Deferred_values.plonk
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
            Bulletproof_challenge.map ~f:scalar r )
    ; xi = scalar xi
    ; b
    }
end

include Make (Wrap_main_inputs)

let challenge_polynomial = G.challenge_polynomial
