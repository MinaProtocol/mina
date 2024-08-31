(* base58_check.ml : implement Base58Check algorithm
   see: https://www.oreilly.com/library/view/mastering-bitcoin-2nd/9781491954379/ch04.html#base58
   also: https://datatracker.ietf.org/doc/html/draft-msporny-base58-03

   the algorithm is modified for long strings, to apply encoding on chunks of the input
*)

open Core_kernel

exception Invalid_base58_checksum of string

exception Invalid_base58_version_byte of (char * string)

exception Invalid_base58_check_length of string

exception Invalid_base58_character of string

(* same as Bitcoin alphabet *)
let mina_alphabet =
  B58.make_alphabet "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

let version_len = 1

let checksum_len = 4

module Make (M : sig
  val description : string

  val version_byte : char
end) =
struct
  let version_byte = M.version_byte

  let version_string = String.make 1 version_byte

  let max_length = 8192

  let compute_checksum payload =
    (* double-hash using SHA256 *)
    let open Digestif.SHA256 in
    let ctx0 = init () in
    let ctx1 = feed_string ctx0 version_string in
    let ctx2 = feed_string ctx1 payload in
    let first_hash = get ctx2 |> to_raw_string in
    let ctx3 = feed_string ctx0 first_hash in
    let second_hash = get ctx3 |> to_raw_string in
    second_hash |> String.sub ~pos:0 ~len:checksum_len

  (* we don't name this with _exn, we don't expect to raise an exception
     if we do, we're encoding types that shouldn't be encoded
  *)
  let encode payload =
    let len = String.length payload in
    if len > max_length then
      failwithf
        "String is too long (%d bytes) to Base58Check-encode, max length is %d"
        len max_length () ;
    let checksum = compute_checksum payload in
    let bytes = version_string ^ payload ^ checksum |> Bytes.of_string in
    B58.encode mina_alphabet bytes |> Bytes.to_string

  let decode_exn s =
    let bytes = Bytes.of_string s in
    let decoded =
      try B58.decode mina_alphabet bytes |> Bytes.to_string
      with B58.Invalid_base58_character ->
        raise (Invalid_base58_character M.description)
    in
    let len = String.length decoded in
    (* input must be at least as long as the version byte and checksum *)
    if len < version_len + checksum_len then
      raise (Invalid_base58_check_length M.description) ;
    if not (Char.equal decoded.[0] version_byte) then
      raise (Invalid_base58_version_byte (decoded.[0], M.description)) ;
    let checksum =
      String.sub decoded
        ~pos:(String.length decoded - checksum_len)
        ~len:checksum_len
    in
    let payload =
      String.sub decoded ~pos:1 ~len:(len - version_len - checksum_len)
    in
    if not (String.equal checksum (compute_checksum payload)) then
      raise (Invalid_base58_checksum M.description) ;
    payload

  let decode s =
    let error_str e desc =
      sprintf "Error decoding %s\nInvalid base58 %s in %s" s e desc
    in
    try Ok (decode_exn s) with
    | Invalid_base58_character str ->
        Or_error.error_string (error_str "character" str)
    | Invalid_base58_check_length str ->
        Or_error.error_string (error_str "check length" str)
    | Invalid_base58_checksum str ->
        Or_error.error_string (error_str "checksum" str)
    | Invalid_base58_version_byte (ch, str) ->
        Or_error.error_string
          (error_str
             (sprintf "version byte \\x%02X, expected \\x%02X" (Char.to_int ch)
                (Char.to_int version_byte) )
             str )
end

module Version_bytes = Version_bytes
