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

  let chunk_size = 8192

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

  let encode_unchunked payload =
    (* this function is not exposed in the .mli file, so it's only called
       locally, calls are guarded by checking the input length
    *)
    let checksum = compute_checksum payload in
    let bytes = version_string ^ payload ^ checksum |> Bytes.of_string in
    B58.encode mina_alphabet bytes |> Bytes.to_string

  (* the chunk marker prefixes encodings that are chunked

     it must not appear in the alphabet above, so it can
     never appear in Base58-encoded text

     it does appear to be mouse-selectable when it appears with
     alphanumeric text (in Linux, at least)

     do not change it!
  *)
  let chunk_marker = '0'

  let encode_chunked payload =
    let split s =
      let len = String.length s in
      if len <= chunk_size then (s, "")
      else
        ( String.sub s ~pos:0 ~len:chunk_size
        , String.sub s ~pos:chunk_size ~len:(len - chunk_size) )
    in
    let rec get_chunks acc cs =
      match split cs with
      | l1, "" ->
          List.rev (l1 :: acc)
      | l1, l2 ->
          get_chunks (l1 :: acc) l2
    in
    let chunks = get_chunks [] payload in
    (* represent length as 4 hex digits, which
       is mouse-selectable (note that 0 does not appear
       in the alphabet above)
    *)
    let len_prefixed_encoded_chunks =
      List.map chunks ~f:(fun chunk ->
          let encoded = encode_unchunked chunk in
          sprintf "%04X%s" (String.length encoded) encoded)
    in
    String.concat (String.of_char chunk_marker :: len_prefixed_encoded_chunks)

  let encode payload =
    if String.length payload <= chunk_size then encode_unchunked payload
    else encode_chunked payload

  let decode_unchunked_exn s =
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
    if not (Char.equal decoded.[0] version_byte) then
      raise (Invalid_base58_version_byte (decoded.[0], M.description)) ;
    payload

  let decode_chunked_exn s =
    let hex_char_to_int =
      let code_0 = Char.to_int '0' in
      let code_9 = Char.to_int '9' in
      let code_A = Char.to_int 'A' in
      let code_a = Char.to_int 'a' in
      let code_F = Char.to_int 'F' in
      let code_f = Char.to_int 'f' in
      fun c ->
        let code = Char.to_int c in
        if code >= code_0 && code <= code_9 then code - code_0
        else if code >= code_A && code <= code_F then code - code_A + 0xA
        else if code >= code_a && code <= code_f then code - code_a + 0xA
        else failwithf "hex_char_to_int: got invalid character: %c" c ()
    in
    (* remove chunk marker *)
    let stitched = String.sub s ~pos:1 ~len:(String.length s - 1) in
    let split s =
      (* interpret 4 hex char length prefix *)
      let len =
        (hex_char_to_int s.[0] lsl 12)
        + (hex_char_to_int s.[1] lsl 8)
        + (hex_char_to_int s.[2] lsl 4)
        + hex_char_to_int s.[3]
      in
      ( String.sub s ~pos:4 ~len
      , String.sub s ~pos:(4 + len) ~len:(String.length s - (4 + len)) )
    in
    let rec rechunk acc s =
      match split s with
      | chunk, "" ->
          List.rev (chunk :: acc)
      | chunk, rest ->
          rechunk (chunk :: acc) rest
    in
    let chunks = rechunk [] stitched in
    List.map chunks ~f:decode_unchunked_exn |> String.concat

  let decode_exn s =
    if String.is_empty s then failwith "decode_exn: empty input" ;
    if Char.equal s.[0] chunk_marker then decode_chunked_exn s
    else decode_unchunked_exn s

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
                (Char.to_int version_byte))
             str)
end

module Version_bytes = Version_bytes

let%test_module "base58check tests" =
  ( module struct
    module Base58_check = Make (struct
      let description = "Base58check tests"

      let version_byte = '\x53'
    end)

    open Base58_check

    let test_roundtrip payload =
      let encoded = encode payload in
      let payload' = decode_exn encoded in
      String.equal payload payload'

    let%test "empty_string" = test_roundtrip ""

    let%test "nonempty_string" =
      test_roundtrip "Somewhere, over the rainbow, way up high"

    let%test "longer_string" =
      test_roundtrip
        "Someday, I wish upon a star, wake up where the clouds are far behind \
         me, where trouble melts like lemon drops, High above the chimney top, \
         that's where you'll find me"

    let%test "invalid checksum" =
      try
        let encoded = encode "Bluer than velvet were her eyes" in
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
        let _payload = decode_exn encoded_bad_checksum in
        false
      with Invalid_base58_checksum _ -> true

    let%test "invalid length" =
      try
        let _payload = decode_exn "abcd" in
        false
      with Invalid_base58_check_length _ -> true

    let%test "round trip with chunking" =
      let para =
        {| Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
                    incididunt ut labore et dolore magna aliqua. Integer quis auctor
                    elit sed vulputate mi sit amet. Sapien pellentesque habitant morbi
                    tristique senectus et. Eu tincidunt tortor aliquam nulla facilisi
                    cras fermentum odio. Tortor pretium viverra suspendisse
                    potenti. Faucibus vitae aliquet nec ullamcorper sit amet risus
                    nullam eget. Quis auctor elit sed vulputate mi sit amet mauris
                    commodo. Porttitor rhoncus dolor purus non enim praesent
                    elementum. Enim tortor at auctor urna nunc id cursus metus
                    aliquam. Commodo odio aenean sed adipiscing diam donec. Maecenas
                    ultricies mi eget mauris pharetra et. Morbi tempus iaculis urna id
                    volutpat lacus laoreet non. Nulla facilisi etiam dignissim diam
                    quis enim lobortis scelerisque. Sit amet dictum sit amet
                    justo. Odio eu feugiat pretium nibh. Feugiat in ante metus
                    dictum. Tempus urna et pharetra pharetra massa massa. Purus in
                    mollis nunc sed id semper risus in. Leo in vitae turpis
                    massa. Pellentesque habitant morbi tristique senectus et netus.
                  |}
      in
      let page = String.concat [ para; para; para; para; para ] in
      let book = String.concat [ page; page; page; page; page ] in
      (* length of book is about 35K, several chunks *)
      let encoded = encode book in
      let decoded = decode_exn encoded in
      String.equal decoded book
  end )
