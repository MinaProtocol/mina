open Core_kernel

let digest_size_in_bits = 256

let digest_size_in_bytes = digest_size_in_bits / 8

module T = Digestif.Make_BLAKE2S (struct
  let digest_size = digest_size_in_bytes
end)

include T

module Stable = struct
  module V1 = struct
    module T = struct
      type t = T.t [@@deriving version {asserted; unnumbered}]

      include Binable.Of_stringable (struct
        type nonrec t = t

        let of_string = of_raw_string

        let to_string = to_raw_string
      end)
    end

    include T
  end

  module Latest = V1
end

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
  Quickcheck.test ~trials:5 String.quickcheck_generator ~f:(fun s ->
      [%test_eq: string] s (bits_to_string (string_to_bits s)) )
