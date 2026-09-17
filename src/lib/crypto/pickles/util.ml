open Core_kernel
open Pickles_types

let rec absorb :
    type a g1 g1_opt f scalar.
       absorb_field:(f -> unit)
    -> absorb_scalar:(scalar -> unit)
    -> g1_to_field_elements:(g1 -> f list)
    -> mask_g1_opt:(g1_opt -> g1)
    -> ( a
       , < scalar : scalar ; g1 : g1 ; g1_opt : g1_opt ; base_field : f > )
       Type.t
    -> a
    -> unit =
 fun ~absorb_field ~absorb_scalar ~g1_to_field_elements ~mask_g1_opt ty t ->
  match ty with
  | Type.PC ->
      List.iter ~f:absorb_field (g1_to_field_elements t)
  | Type.Field ->
      absorb_field t
  | Type.Scalar ->
      absorb_scalar t
  | Type.Without_degree_bound ->
      Array.iter
        ~f:(Fn.compose (List.iter ~f:absorb_field) g1_to_field_elements)
        t
  | Type.With_degree_bound ->
      let Pickles_types.Plonk_types.Poly_comm.With_degree_bound.
            { unshifted; shifted } =
        t
      in
      let absorb x =
        absorb ~absorb_field ~absorb_scalar ~g1_to_field_elements ~mask_g1_opt
          Type.PC (mask_g1_opt x)
      in
      Array.iter unshifted ~f:absorb ;
      absorb shifted
  | ty1 :: ty2 ->
      let absorb t =
        absorb t ~absorb_field ~absorb_scalar ~g1_to_field_elements ~mask_g1_opt
      in
      let t1, t2 = t in
      absorb ty1 t1 ; absorb ty2 t2

module Make (Impl : Kimchi_pasta_snarky_backend.Snark_intf) = struct
  module Bignum_bigint = Bigint
  open Impl

  (** [ones_vector (module I) ~first_zero n] returns a vector of booleans of
   length n which is all ones until position [first_zero], at which it is zero,
   and zero thereafter. *)
  let ones_vector :
      type n. first_zero:Impl.Field.t -> n Nat.t -> (Boolean.var, n) Vector.t =
   fun ~first_zero n ->
    let rec go :
        type m. Boolean.var -> int -> m Nat.t -> (Boolean.var, m) Vector.t =
     fun value i m ->
      match[@warning "-45"] m with
      | Pickles_types.Nat.Z ->
          Pickles_types.Vector.[]
      | Pickles_types.Nat.S m ->
          let value =
            Boolean.(value && not (Field.equal first_zero (Field.of_int i)))
          in
          Pickles_types.Vector.(value :: go value (i + 1) m)
    in
    go Boolean.true_ 0 n

  let seal (x : Impl.Field.t) : Impl.Field.t =
    with_label "Util.seal" (fun () ->
      match Field.to_constant_and_terms x with
      | None, [ (x, i) ] when Field.Constant.(equal x one) ->
          Snarky_backendless.Cvar.Var i
      | Some c, [] ->
          Field.constant c
      | _ ->
          let y = exists Field.typ ~compute:As_prover.(fun () -> read_var x) in
          Field.Assert.equal x y ; y )

  (* [c mod 2^128] and [c / 2^128], as field constants. *)
  let split_constant_128 (c : Bignum_bigint.t) :
      Field.Constant.t * Field.Constant.t =
    let to_field b = Bigint.(to_field (of_bignum_bigint b)) in
    let pow2_128 = Bignum_bigint.(shift_left one 128) in
    ( to_field Bignum_bigint.(c % pow2_128)
    , to_field (Bignum_bigint.shift_right c 128) )

  (* Asserts [lo + 2^128 hi < bound] as integers, for [lo] and [hi] below
     [2^128], with one range-checked difference: [bound_lo - 1 - lo] when
     [hi = bound_hi], else [bound_hi - 1 - hi]. A negative difference wraps
     past [2^128] and fails, so the first case pins [lo < bound_lo] and the
     second [hi < bound_hi]. A caller that does not range-check [lo] relies
     on its consumers to bound it. *)
  let assert_split_below ~assert_128_bits ~lo ~hi (bound : Bignum_bigint.t) =
    let bound_lo, bound_hi = split_constant_128 bound in
    let hi_is_top = Field.equal hi (Field.constant bound_hi) in
    let d =
      Field.if_ hi_is_top
        ~then_:Field.(constant Constant.(bound_lo - one) - lo)
        ~else_:Field.(constant Constant.(bound_hi - one) - hi)
    in
    assert_128_bits d

  (* Splits [x] as [lo + 2^128 hi] below [bound], with [hi] and, under
     [constrain_low_bits], [lo] range-checked to 128 bits, and returns
     [lo]. *)
  let split_128_below ~constrain_low_bits ~assert_128_bits
      (bound : Bignum_bigint.t) x =
    let pow2 =
      (* 2 ^ n *)
      let rec pow2 x i =
        if i = 0 then x else pow2 Field.Constant.(x + x) (i - 1)
      in
      fun n -> pow2 Field.Constant.one n
    in
    let lo, hi =
      exists
        Typ.(field * field)
        ~compute:(fun () ->
          let lo, hi =
            Field.Constant.unpack (As_prover.read_var x)
            |> Fn.flip List.split_n 128
          in
          (Field.Constant.project lo, Field.Constant.project hi) )
    in
    assert_128_bits hi ;
    if constrain_low_bits then assert_128_bits lo ;
    Field.Assert.equal x Field.(lo + scale hi (pow2 128)) ;
    assert_split_below ~assert_128_bits ~lo ~hi bound ;
    lo

  (* The low half of [x]'s canonical representative: the split below the
     field modulus, so the prover has no alias to choose. *)
  let lowest_128_bits ~constrain_low_bits ~assert_128_bits x =
    split_128_below ~constrain_low_bits ~assert_128_bits Field.size x

  (* The IPA base [(x, y)] with the square-root sign pinned: [(x, y')] with
     [y' = +-y] and [y'] at most [(p - 1) / 2] as an integer. *)
  let lower_half_point ~assert_128_bits ((x, y) : Field.t * Field.t) =
    let half = Bignum_bigint.((Field.size + one) / of_int 2) in
    let is_upper =
      exists Boolean.typ
        ~compute:
          As_prover.(
            fun () ->
              let y = Bigint.(to_bignum_bigint (of_field (read_var y))) in
              Bignum_bigint.(y >= half))
    in
    let y =
      Field.if_ is_upper
        ~then_:(Field.scale y Field.Constant.(negate one))
        ~else_:y
    in
    ignore
      ( split_128_below ~constrain_low_bits:true ~assert_128_bits half y
        : Field.t ) ;
    (x, y)
end

module Step = Make (Kimchi_pasta_snarky_backend.Step_impl)
module Wrap = Make (Kimchi_pasta_snarky_backend.Wrap_impl)
