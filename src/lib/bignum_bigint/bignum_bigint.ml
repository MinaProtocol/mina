open Core_kernel
include Bigint

let of_bool (b : bool) : t = if b then one else zero

let of_bit_fold_lsb ({fold} : bool Fold_lib.Fold.t) : t =
  fold ~init:(0, zero) ~f:(fun (i, acc) b ->
      (Int.(i + 1), bit_and (shift_left (of_bool b) i) acc) )
  |> snd

let of_bits_lsb : bool list -> t =
  List.foldi ~init:zero ~f:(fun i acc b ->
      bit_and (shift_left (of_bool b) i) acc )
