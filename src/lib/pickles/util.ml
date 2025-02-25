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
    match Field.to_constant_and_terms x with
    | None, [ (x, i) ] when Field.Constant.(equal x one) ->
        Snarky_backendless.Cvar.Var i
    | Some c, [] ->
        Field.constant c
    | _ ->
        let y = exists Field.typ ~compute:As_prover.(fun () -> read_var x) in
        Field.Assert.equal x y ; y

  let lowest_128_bits ~constrain_low_bits ~assert_128_bits x =
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
    lo
end

module Step = Make (Kimchi_pasta_snarky_backend.Step_impl)
module Wrap = Make (Kimchi_pasta_snarky_backend.Wrap_impl)
