open Core_kernel
open Import
open Pickles_types

type m = Abc.Label.t = A | B | C

let rec absorb : type a g1 f scalar.
       absorb_field:(f -> unit)
    -> absorb_scalar:(scalar -> unit)
    -> g1_to_field_elements:(g1 -> f list)
    -> (a, < scalar: scalar ; g1: g1 >) Type.t
    -> a
    -> unit =
 fun ~absorb_field ~absorb_scalar ~g1_to_field_elements ty t ->
  match ty with
  | PC ->
      List.iter ~f:absorb_field (g1_to_field_elements t)
  | Scalar ->
      absorb_scalar t
  | Without_degree_bound ->
      Array.iter
        ~f:(Fn.compose (List.iter ~f:absorb_field) g1_to_field_elements)
        t
  | With_degree_bound ->
      Array.iter t.unshifted ~f:(fun t ->
          absorb ~absorb_field ~absorb_scalar ~g1_to_field_elements PC t ) ;
      absorb ~absorb_field ~absorb_scalar ~g1_to_field_elements PC t.shifted
  | ty1 :: ty2 ->
      let absorb t =
        absorb t ~absorb_field ~absorb_scalar ~g1_to_field_elements
      in
      let t1, t2 = t in
      absorb ty1 t1 ; absorb ty2 t2

let ones_vector : type f n.
       first_zero:f Snarky.Cvar.t
    -> (module Snarky.Snark_intf.Run with type field = f)
    -> n Nat.t
    -> (f Snarky.Cvar.t Snarky.Boolean.t, n) Vector.t =
 fun ~first_zero (module Impl) n ->
  let open Impl in
  let rec go : type m.
      Boolean.var -> int -> m Nat.t -> (Boolean.var, m) Vector.t =
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

let split_last xs =
  let rec go acc = function
    | [x] ->
        (List.rev acc, x)
    | x :: xs ->
        go (x :: acc) xs
    | [] ->
        failwith "Empty list"
  in
  go [] xs
