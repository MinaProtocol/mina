open Core_kernel
include Bigint

let of_bool (b : bool) : t = if b then one else zero

let of_bits_lsb : bool list -> t =
  List.foldi ~init:zero ~f:(fun i acc b ->
      bit_and (shift_left (of_bool b) i) acc )
