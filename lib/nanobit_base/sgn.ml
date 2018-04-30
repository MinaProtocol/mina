open Core
open Snark_params.Tick

type t =
  | Pos
  | Neg
[@@deriving sexp, bin_io]

let neg_one = Field.(negate one)

let to_field = function
  | Pos -> Field.one
  | Neg -> neg_one

let of_field x =
  if Field.equal x Field.one
  then Pos
  else if Field.equal x neg_one
  then Neg
  else failwith "Sgn.of_field: Expected positive or negative 1"

type var = Cvar.t

let typ : (var, t) Typ.t =
  let open Typ in
  { check = (fun x -> assert_r1cs x x (Cvar.constant Field.one))
  ; store = (fun t -> Store.store (to_field t))
  ; read = (fun x -> Read.(read x >>| of_field))
  ; alloc = Alloc.alloc
  }

module Checked = struct
  let two = Field.of_int 2
  let neg_two = Field.negate two
  let one_half = Field.inv two
  let neg_one_half = Field.negate one_half

  let is_pos (v : var) =
    Boolean.Unsafe.of_cvar
      Cvar.(Infix.(one_half * (v + constant Field.one)))

  let is_neg (v : var) =
    Boolean.Unsafe.of_cvar
      Cvar.(Infix.(neg_one_half * (v - constant Field.one)))

  let pos_if_true (b : Boolean.var) =
    Cvar.(Infix.(two * (b :> Cvar.t) - constant Field.one))

  let neg_if_true (b : Boolean.var) =
    Cvar.(Infix.(neg_two * (b :> Cvar.t) + constant Field.one))

  let neg = Cvar.constant (to_field Neg)
  let pos = Cvar.constant (to_field Pos)
end
