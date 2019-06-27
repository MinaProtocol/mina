(* base58_check.ml : implement Base58Check algorithm
   see: https://www.oreilly.com/library/view/mastering-bitcoin-2nd/9781491954379/ch04.html#base58
*)

open Core_kernel

exception Invalid_base58_checksum

exception Invalid_base58_version_byte

exception Invalid_base58_check_length

(* same as Bitcoin alphabet *)
let coda_alphabet =
  B58.make_alphabet
    "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

let version_len = 1

let checksum_len = 4

let compute_checksum ~version_string ~payload =
  (* double-hash using SHA256 *)
  let open Digestif.SHA256 in
  let ctx0 = init () in
  let ctx1 = feed_string ctx0 version_string in
  let ctx2 = feed_string ctx1 payload in
  let first_hash = get ctx2 |> to_raw_string in
  let ctx3 = feed_string ctx0 first_hash in
  let second_hash = get ctx3 |> to_raw_string in
  second_hash |> String.sub ~pos:0 ~len:checksum_len

let encode ~(version_byte : char) ~(payload : string) =
  let version_string = String.make 1 version_byte in
  let checksum = compute_checksum ~version_string ~payload in
  let bytes = version_string ^ payload ^ checksum |> Bytes.of_string in
  B58.encode coda_alphabet bytes |> Bytes.to_string

let decode_exn ~(version_byte : char) s =
  let bytes = Bytes.of_string s in
  let decoded = B58.decode coda_alphabet bytes |> Bytes.to_string in
  let len = String.length decoded in
  (* input must be at least as long as the version byte and checksum *)
  if len < version_len + checksum_len then raise Invalid_base58_check_length ;
  let version_string = String.sub decoded ~pos:0 ~len:version_len in
  let checksum =
    String.sub decoded
      ~pos:(String.length decoded - checksum_len)
      ~len:checksum_len
  in
  let payload =
    String.sub decoded ~pos:1 ~len:(len - version_len - checksum_len)
  in
  if not (String.equal checksum (compute_checksum ~version_string ~payload))
  then raise Invalid_base58_checksum ;
  if not (Char.equal decoded.[0] version_byte) then
    raise Invalid_base58_version_byte ;
  payload

let decode ~(version_byte : char) s =
  try Ok (decode_exn ~version_byte s) with
  | B58.Invalid_base58_character ->
      Or_error.error_string "Invalid base58 character"
  | Invalid_base58_check_length ->
      Or_error.error_string "Invalid base58 check length"
  | Invalid_base58_checksum ->
      Or_error.error_string "Invalid base58 checksum"
  | Invalid_base58_version_byte ->
      Or_error.error_string "Invalid base58 version byte"

module Version_bytes = Version_bytes

let%test_module "empty string" =
  ( module struct
    let test_roundtrip version_byte payload =
      let encoded = encode ~version_byte ~payload in
      let payload' = decode_exn ~version_byte encoded in
      String.equal payload payload'

    let%test "empty_string" = test_roundtrip '\x57' ""

    let%test "nonempty_string" =
      test_roundtrip '\x31' "Somewhere, over the rainbow, way up high"

    let%test "longer_string" =
      test_roundtrip '\xFE'
        "Someday, I wish upon a star, wake up where the clouds are far behind \
         me, where trouble melts like lemon drops, High above the chimney \
         top, that's where you'll find me"

    let%test "invalid checksum" =
      try
        let version_byte = '\xAC' in
        let encoded =
          encode ~version_byte ~payload:"Bluer than velvet were her eyes"
        in
        let bytes = Bytes.of_string encoded in
        let len = Bytes.length bytes in
        let last_ch = Bytes.get bytes (len - 1) in
        (* change last byte to invalidate checksum *)
        let new_last_ch =
          if Char.equal last_ch '\xFF' then '\x00'
          else Char.of_int_exn (Char.to_int last_ch + 1)
        in
        Bytes.set bytes (len - 1) new_last_ch ;
        let encoded_bad_checksum = Bytes.to_string bytes in
        let _payload = decode_exn ~version_byte encoded_bad_checksum in
        false
      with Invalid_base58_checksum -> true

    let%test "invalid length" =
      try
        let _payload = decode_exn ~version_byte:'\x53' "abcd" in
        false
      with Invalid_base58_check_length -> true
  end )
