open Core_kernel
open Snark_params.Tick

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Sgn_type.Sgn.Stable.V1.t = Pos | Neg
    [@@deriving sexp, hash, compare, equal, yojson]

    let to_latest = Fn.id
  end
end]

let gen =
  Quickcheck.Generator.map Bool.quickcheck_generator ~f:(fun b ->
      if b then Pos else Neg )

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
  Typ
    { check = (fun x -> assert_r1cs x x (Field.Var.constant Field.one))
    ; var_to_fields = (fun t -> ([| t |], ()))
    ; var_of_fields = (fun (ts, ()) -> ts.(0))
    ; value_to_fields = (fun t -> ([| to_field t |], ()))
    ; value_of_fields = (fun (ts, ()) -> of_field_exn ts.(0))
    ; size_in_field_elements = 1
    ; constraint_system_auxiliary = (fun () -> ())
    }

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
