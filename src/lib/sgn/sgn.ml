open Core_kernel
open Snark_params.Tick

type t = Pos | Neg [@@deriving sexp, bin_io, hash, compare, eq]

let gen = Quickcheck.Generator.map Bool.gen ~f:(fun b -> if b then Pos else Neg)

let negate = function Pos -> Neg | Neg -> Pos

let neg_one = Field.(negate one)

let to_field = function Pos -> Field.one | Neg -> neg_one

let of_field_exn x =
  if Field.equal x Field.one then Pos
  else if Field.equal x neg_one then Neg
  else failwith "Sgn.of_field: Expected positive or negative 1"

type var = Field.Checked.t

let typ : (var, t) Typ.t =
  let open Typ in
  { check= (fun x -> assert_r1cs x x (Field.Checked.constant Field.one))
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
      Infix.(one_half * (v + constant Field.one)))

  let is_neg (v : var) =
    Boolean.Unsafe.of_cvar
      (let open Field.Checked in
      Infix.(neg_one_half * (v - constant Field.one)))

  let pos_if_true (b : Boolean.var) =
    let open Field.Checked in
    Infix.((two * (b :> Field.Checked.t)) - constant Field.one)

  let neg_if_true (b : Boolean.var) =
    let open Field.Checked in
    Infix.((neg_two * (b :> Field.Checked.t)) + constant Field.one)

  let negate t = Field.Checked.scale t neg_one

  let constant = Fn.compose Field.Checked.constant to_field

  let neg = constant Neg

  let pos = constant Pos

  let if_ = Field.Checked.if_
end
