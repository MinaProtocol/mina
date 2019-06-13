open Core_kernel

type t = Big_int.big_int

let equal = Big_int.eq_big_int

let num_bits = Big_int.num_bits_big_int

let shift_right = Big_int.shift_right_big_int

let shift_left = Big_int.shift_left_big_int

let log_and = Big_int.and_big_int

let log_or = Big_int.or_big_int

let of_int = Big_int.big_int_of_int

let test_bit t i =
  equal (log_and Big_int.unit_big_int (shift_right t i)) Big_int.unit_big_int

let to_bytes x =
  let n = num_bits x in
  let num_bytes = (n + 7) / 8 in
  String.init num_bytes ~f:(fun byte ->
      let c i =
        let bit = (8 * byte) + i in
        if test_bit x bit then 1 lsl i else 0
      in
      Char.of_int_exn
        (c 0 lor c 1 lor c 2 lor c 3 lor c 4 lor c 5 lor c 6 lor c 7) )

let of_bytes x =
  String.foldi x ~init:Big_int.zero_big_int ~f:(fun i acc c ->
      log_or acc (shift_left (of_int (Char.to_int c)) (8 * i)) )

let ( + ) = Big_int.add_big_int

let ( - ) = Big_int.sub_big_int

let ( * ) = Big_int.mult_big_int

let ( % ) = Big_int.mod_big_int

let ( // ) = Big_int.div_big_int

let ( < ) = Big_int.lt_big_int

let to_int_exn = Big_int.int_of_big_int

let compare = Big_int.compare_big_int

module String_hum = struct
  type nonrec t = t

  let of_string = Big_int.big_int_of_string

  let to_string = Big_int.string_of_big_int
end

include Sexpable.Of_stringable (String_hum)

include (String_hum : Stringable.S with type t := t)

include Binable.Of_stringable (struct
  type nonrec t = t

  let of_string = of_bytes

  let to_string = to_bytes
end)
