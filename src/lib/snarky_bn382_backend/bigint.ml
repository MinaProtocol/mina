open Core
open Snarky_bn382

module R = struct
  open Bigint

  let length_in_bytes = 48

  type nonrec t = t

  let to_bigstring t =
    let limbs = to_data t in
    Bigstring.init length_in_bytes ~f:(fun i -> Ctypes.(!@(limbs +@ i)))

  let of_bigstring s =
    let ptr = Ctypes.bigarray_start Ctypes.array1 s in
    let t = of_data ptr in
    Caml.Gc.finalise delete t ; t

  include Binable.Of_binable
            (Bigstring.Stable.V1)
            (struct
              type nonrec t = t

              let to_binable = to_bigstring

              let of_binable = of_bigstring
            end)

  let test_bit = test_bit

  let of_data bs ~bitcount =
    assert (bitcount <= length_in_bytes * 8) ;
    of_bigstring bs

  let of_decimal_string = of_decimal_string

  let of_numeral s ~base = of_numeral s (String.length s) base

  let compare x y =
    match Unsigned.UInt8.to_int (compare x y) with 255 -> -1 | x -> x
end
