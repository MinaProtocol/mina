open Core_kernel
open Snark_params.Tick
include Sgn_type.Sgn

let gen = Quickcheck.Generator.map Bool.gen ~f:(fun b -> if b then Pos else Neg)

let negate = function Pos -> Neg | Neg -> Pos

let neg_one = Field.(negate one)

let to_field = function Pos -> Field.one | Neg -> neg_one

let of_field_exn x =
  if Field.equal x Field.one then Pos
  else if Field.equal x neg_one then Neg
  else failwith "Sgn.of_field: Expected positive or negative 1"

type var = Field.Var.t

let typ : (var, t) Typ.t =
  let open Typ in
  { check= (fun x -> assert_r1cs x x (Field.Var.constant Field.one))
  ; store= (fun t -> Store.store (to_field t))
  ; read= (fun x -> Read.(read x >>| of_field_exn))
  ; alloc= Alloc.alloc }

module Checked = struct
  let two = Field.of_int 2

  let neg_two = Field.negate two

  let one_half = Field.inv two

  let neg_one_half = Field.negate one_half

  let is_pos (v : var) =
    Boolean.Unsafe.of_cvar
      (let open Field.Checked in
      one_half * (v + Field.Var.constant Field.one))

  let is_neg (v : var) =
    Boolean.Unsafe.of_cvar
      (let open Field.Checked in
      neg_one_half * (v - Field.Var.constant Field.one))

  let pos_if_true (b : Boolean.var) =
    let open Field.Checked in
    (two * (b :> Field.Var.t)) - Field.Var.constant Field.one

  let neg_if_true (b : Boolean.var) =
    let open Field.Checked in
    (neg_two * (b :> Field.Var.t)) + Field.Var.constant Field.one

  let negate t = Field.Var.scale t neg_one

  let constant = Fn.compose Field.Var.constant to_field

  let neg = constant Neg

  let pos = constant Pos

  let if_ = Field.Checked.if_
end
