open Core_kernel

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
  | PC ->
      List.iter ~f:absorb_field (g1_to_field_elements t)
  | Field ->
      absorb_field t
  | Scalar ->
      absorb_scalar t
  | Without_degree_bound ->
      Array.iter
        ~f:(Fn.compose (List.iter ~f:absorb_field) g1_to_field_elements)
        t
  | With_degree_bound ->
      Array.iter t.unshifted ~f:(fun t ->
          absorb ~absorb_field ~absorb_scalar ~g1_to_field_elements ~mask_g1_opt
            PC (mask_g1_opt t) ) ;
      absorb ~absorb_field ~absorb_scalar ~g1_to_field_elements ~mask_g1_opt PC
        (mask_g1_opt t.shifted)
  | ty1 :: ty2 ->
      let absorb t =
        absorb t ~absorb_field ~absorb_scalar ~g1_to_field_elements ~mask_g1_opt
      in
      let t1, t2 = t in
      absorb ty1 t1 ; absorb ty2 t2

let ones_vector :
    type f n.
       first_zero:f Snarky_backendless.Cvar.t
    -> (module Snarky_backendless.Snark_intf.Run with type field = f)
    -> n Pickles_types.Nat.t
    -> ( f Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t
       , n )
       Pickles_types.Vector.t =
 fun ~first_zero (module Impl) n ->
  let open Impl in
  let rec go :
      type m.
         Boolean.var
      -> int
      -> m Pickles_types.Nat.t
      -> (Boolean.var, m) Pickles_types.Vector.t =
   fun value i m ->
    match m with
    | Z ->
        []
    | S m ->
        let value =
          Boolean.(value && not (Field.equal first_zero (Field.of_int i)))
        in
        value :: go value (i + 1) m
  in
  go Boolean.true_ 0 n

let seal (type f)
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = f)
    (x : Impl.Field.t) : Impl.Field.t =
  let open Impl in
  match Field.to_constant_and_terms x with
  | None, [ (x, i) ] when Field.Constant.(equal x one) ->
      Snarky_backendless.Cvar.Var i
  | Some c, [] ->
      Field.constant c
  | _ ->
      let y = exists Field.typ ~compute:As_prover.(fun () -> read_var x) in
      Field.Assert.equal x y ; y

let lowest_128_bits (type f) ~constrain_low_bits ~assert_128_bits
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = f) x =
  let open Impl in
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
