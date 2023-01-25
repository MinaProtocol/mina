open Core_kernel
open Currency.Amount

type unsigned = t

type t = unsigned

let if_ b ~then_ ~else_ = if b then then_ else else_

module Signed = struct
  include Signed

  let if_ = if_

  let is_pos (t : t) = Sgn.equal t.sgn Pos

  let is_neg (t : t) = Sgn.equal t.sgn Neg
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
