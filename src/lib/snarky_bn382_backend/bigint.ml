open Core
open Snarky_bn382

module R = struct
  open Bigint

  let length_in_bytes = 48

  type nonrec t = t

  let to_hex_string t =
    let data = to_data t in
    String.concat
      (List.init length_in_bytes ~f:(fun i ->
           sprintf "%02x" (Char.to_int Ctypes.(!@(data +@ i))) ))
    |> sprintf "0x%s"

  let sexp_of_t t = to_hex_string t |> Sexp.of_string

  let to_bigstring t =
    let limbs = to_data t in
    Bigstring.init length_in_bytes ~f:(fun i -> Ctypes.(!@(limbs +@ i)))

  let of_bigstring s =
    let ptr = Ctypes.bigarray_start Ctypes.array1 s in
    let t = of_data ptr in
    Caml.Gc.finalise delete t ; t

  let of_hex_string s =
    assert (s.[0] = '0' && s.[1] = 'x') ;
    of_bigstring (Hex.decode ~pos:2 ~init:Bigstring.init s)

  let%test_unit "hex test" =
    let bytes =
      String.init length_in_bytes ~f:(fun _ -> Char.of_int_exn (Random.int 255))
    in
    let h = "0x" ^ Hex.encode bytes in
    [%test_eq: string] h (to_hex_string (of_hex_string h))

  let t_of_sexp s = of_hex_string (String.t_of_sexp s)

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
