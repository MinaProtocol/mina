open Core
open Impl

let int_to_bits ~length n =
  let ith_bit i = (n lsr i) land 1 = 1 in
  List.init length ~f:ith_bit
;;

let int_of_bits bs =
  List.foldi bs ~init:0 ~f:(fun i acc b ->
    if b then acc + (1 lsl i) else acc)

let field_to_int x =
  int_of_bits (List.take (Field.unpack x) 62)

module Make (M : sig type t [@@deriving enum] end) = struct
  open M

  let bit_length =
    let n = Int.ceil_log2 (M.max + 1) in
    assert (n < Field.size_in_bits);
    n

  type var = Cvar.t

  let to_field t = Field.of_int (to_enum t)
  let of_field x = Option.value_exn (of_enum (field_to_int x))

  let assert_equal = assert_equal

  let typ : (var, t) Var_spec.t =
    Var_spec.transport Var_spec.field
      ~there:to_field ~back:of_field

  let var_to_bits : var -> (Boolean.var list, _) Checked.t =
    Checked.unpack ~length:bit_length

  let to_bits t =
    int_to_bits ~length:bit_length (to_enum t)

  let if_ b ~(then_ : var) ~(else_ : var) =
    Checked.if_ b ~then_ ~else_

  let var t : var = Cvar.constant (to_field t)

  let (=) = Checked.equal
end

