open Core_kernel

let digest_size_in_bits = 256

let digest_size_in_bytes = 256 / 8

include Digestif.Make_BLAKE2S (struct
  let digest_size = digest_size_in_bytes
end)

(* Little endian *)
let bits_to_string bits =
  let n = Array.length bits in
  let rec make_byte offset acc i =
    let finished = i = 8 || offset + i >= n in
    if finished then Char.of_int_exn acc
    else
      let acc = if bits.(offset + i) then acc lor (1 lsl i) else acc in
      make_byte offset acc (i + 1)
  in
  let len = (n + 7) / 8 in
  String.init len ~f:(fun i -> make_byte (8 * i) 0 0)

let%test_unit "bits_to_string" =
  [%test_eq: string]
    (bits_to_string [|true; false|])
    (String.of_char_list [Char.of_int_exn 1])

let string_to_bits s =
  Array.init
    (8 * String.length s)
    ~f:(fun i ->
      let c = Char.to_int s.[i / 8] in
      let j = i mod 8 in
      (c lsr j) land 1 = 1 )

let%test_unit "string to bits" =
  Quickcheck.test ~trials:5 String.gen ~f:(fun s ->
      [%test_eq: string] s (bits_to_string (string_to_bits s)) )

let digest_field =
  let field_to_bits x =
    let open Crypto_params.Tick0 in
    let n = Bigint.of_field x in
    Array.init Field.size_in_bits ~f:(Bigint.test_bit n)
  in
  fun x -> digest_string (bits_to_string (field_to_bits x))
