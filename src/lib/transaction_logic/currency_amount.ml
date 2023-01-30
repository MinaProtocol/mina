open Core_kernel
open Currency.Amount

type unsigned = t [@@deriving compare, sexp]

type t = unsigned [@@deriving compare, sexp]

let if_ b ~then_ ~else_ = if b then then_ else else_

module Signed = struct
  include Signed

  let if_ = if_

  (* TODO: Remove those from the interface and call is_positive
     and is_negative directly instead. *)
  let is_pos = is_positive

  let is_neg = is_negative
end

let zero = zero

let equal = equal

let add_flagged = add_flagged

let add_signed_flagged (x1 : t) (x2 : Signed.t) : t * [ `Overflow of bool ] =
  let y, `Overflow b = Signed.(add_flagged (of_unsigned x1) x2) in
  match y.sgn with
  | Pos ->
      (y.magnitude, `Overflow b)
  | Neg ->
      (* We want to capture the accurate value so that this will match
         with the values in the snarked logic.
      *)
      let magnitude =
        to_uint64 y.magnitude
        |> Unsigned.UInt64.(mul (sub zero one))
        |> of_uint64
      in
      (magnitude, `Overflow true)

let of_constant_fee = of_fee
