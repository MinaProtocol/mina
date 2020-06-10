open Core_kernel
open Import

module M = struct
  type t = A | B | C [@@deriving eq]
end

type m = M.t = A | B | C

let ms = [A; B; C]

let abc a b c = function A -> a | B -> b | C -> c

let all_but m = List.filter ms ~f:(( <> ) m)

let rec absorb : type a g1 f scalar.
       absorb_field:(f -> unit)
    -> g1_to_field_elements:(g1 -> f list)
    -> pack_scalar:(scalar -> f)
    -> (a, < scalar: scalar ; g1: g1 >) Type.t
    -> a
    -> unit =
 fun ~absorb_field ~g1_to_field_elements ~pack_scalar ty t ->
  match ty with
  | PC ->
      List.iter ~f:absorb_field (g1_to_field_elements t)
  | Scalar ->
      absorb_field (pack_scalar t)
  | ty1 :: ty2 ->
      let absorb t =
        absorb t ~absorb_field ~g1_to_field_elements ~pack_scalar
      in
      let t1, t2 = t in
      absorb ty1 t1 ; absorb ty2 t2

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
