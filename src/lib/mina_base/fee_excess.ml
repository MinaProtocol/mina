(** The unsettled fee excess associated with a transaction or transition.

    This is the sum of the fees charged to the transactions covered, less the
    fees dispensed by the fee transfers among them. A transition whose excess is
    zero has settled all of the fees it collected.

    Fees are always paid in the default token, so a single signed fee is enough
    to represent the excess. (Earlier versions tracked a separate excess for the
    leftmost and rightmost fee token of the covered range, to support fees paid
    in custom tokens.)
*)

open Core
open Currency
open Snark_params
open Tick

[%%versioned
module Stable = struct
  module V2 = struct
    type t = (Fee.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
    [@@deriving compare, equal, hash, sexp, yojson]

    let to_latest = Fn.id
  end
end]

type var = Fee.Signed.var

let typ : (var, t) Typ.t = Fee.Signed.typ

let var_of_t : t -> var = Fee.Signed.Checked.constant

let to_input : t -> Field.t Random_oracle.Input.Chunked.t = Fee.Signed.to_input

let to_input_checked :
    var -> Field.Var.t Random_oracle.Input.Chunked.t Checked.t =
  Fee.Signed.Checked.to_input

let assert_equal_checked : var -> var -> unit Checked.t =
  Fee.Signed.Checked.assert_equal

(** Combine the fee excesses from two transitions. *)
let combine (t1 : t) (t2 : t) : t Or_error.t =
  match Fee.Signed.add t1 t2 with
  | Some t ->
      Or_error.return t
  | None ->
      Or_error.errorf "Error adding fees: overflow."

(* [Fee.Signed.Checked.add] range-checks its result, so an excess that would
   overflow the fee type is rejected here just as it is by [combine]. *)
let combine_checked : var -> var -> var Checked.t = Fee.Signed.Checked.add

let empty : t = Fee.Signed.zero

let is_empty : t -> bool = Fee.Signed.is_zero

let zero = empty

let is_zero = is_empty

let gen : t Quickcheck.Generator.t = Fee.Signed.gen
