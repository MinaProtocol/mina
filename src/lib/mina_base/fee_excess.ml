(** The unsettled fee excess associated with a transaction or transition.

    This is the sum of the fees charged to the transactions covered, less the
    fees dispensed by the fee transfers among them. A transition whose excess is
    zero has settled all of the fees it collected.

    Fees are always paid in the default token, so a single signed fee is enough
    to represent the excess. (Earlier versions tracked a separate excess for the
    leftmost and rightmost fee token of the covered range, to support fees paid
    in custom tokens.)
*)

open Core_kernel
open Currency
open Snark_params
open Tick

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('token, 'fee) t =
            ('token, 'fee) Mina_wire_types.Mina_base.Fee_excess.Poly.V1.t =
        { fee_token_l : 'token
        ; fee_excess_l : 'fee
        ; fee_token_r : 'token
        ; fee_excess_r : 'fee
        }
      [@@deriving compare, equal, hash, sexp, hlist]

      let to_yojson token_to_yojson fee_to_yojson
          { fee_token_l; fee_excess_l; fee_token_r; fee_excess_r } =
        `List
          [ `Assoc
              [ ("token", token_to_yojson fee_token_l)
              ; ("amount", fee_to_yojson fee_excess_l)
              ]
          ; `Assoc
              [ ("token", token_to_yojson fee_token_r)
              ; ("amount", fee_to_yojson fee_excess_r)
              ]
          ]

      let of_yojson token_of_yojson fee_of_yojson = function
        | `List [ `Assoc [ left0; left1 ]; `Assoc [ right0; right1 ] ] -> (
            (* allow for reversed field order: "be liberal in what you accept" *)
            let token_and_excess pair0 pair1 =
              match (pair0, pair1) with
              | ("token", token), ("amount", excess) ->
                  Some (token, excess)
              | ("amount", excess), ("token", token) ->
                  Some (token, excess)
              | _ ->
                  None
            in
            let left = token_and_excess left0 left1 in
            let right = token_and_excess right0 right1 in
            match (left, right) with
            | Some (fee_token_l, fee_excess_l), Some (fee_token_r, fee_excess_r)
              ->
                let open Result.Let_syntax in
                let%map fee_token_l = token_of_yojson fee_token_l
                and fee_excess_l = fee_of_yojson fee_excess_l
                and fee_token_r = token_of_yojson fee_token_r
                and fee_excess_r = fee_of_yojson fee_excess_r in
                { fee_token_l; fee_excess_l; fee_token_r; fee_excess_r }
            | _ ->
                Error "Fee_excess.Poly.Stable.V1.t, unexpected JSON field" )
        | _ ->
            Error "Fee_excess.Poly.Stable.V1.t"
    end
  end]

  [%%define_locally Stable.Latest.(to_yojson, of_yojson)]

  let typ (token_typ : ('token_var, 'token) Typ.t)
      (fee_typ : ('fee_var, 'fee) Typ.t) :
      (('token_var, 'fee_var) t, ('token, 'fee) t) Typ.t =
    Typ.of_hlistable
      [ token_typ; fee_typ; token_typ; fee_typ ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t = (Fee.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
    [@@deriving compare, equal, hash, sexp, yojson]

    let to_latest = Fn.id
  end

  module V1 = struct
    type t =
      ( Token_id.Stable.V2.t
      , (Fee.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t )
      Poly.Stable.V1.t
    [@@deriving compare, equal, hash, sexp, yojson]

    let to_latest ({ fee_token_l; fee_excess_l; fee_token_r; fee_excess_r } : t)
        : Latest.t =
      let default_token_excess fee_token fee_excess =
        if Token_id.equal fee_token Token_id.default then fee_excess
        else if Fee.Signed.is_zero fee_excess then Fee.Signed.zero
        else
          failwith
            "Fee_excess.Stable.V1.to_latest: excess in a non-default token"
      in
      match
        Fee.Signed.add
          (default_token_excess fee_token_l fee_excess_l)
          (default_token_excess fee_token_r fee_excess_r)
      with
      | Some fee_excess ->
          fee_excess
      | None ->
          failwith "Fee_excess.Stable.V1.to_latest: overflow"
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
