(* A token symbol or zkApp URI is any bytes, but a GraphQL response is JSON,
   which must be UTF-8. *)

open Core_kernel

(* Valid UTF-8 is kept; every other byte b becomes U+00b. So this is lossy
   only for a value that is not valid UTF-8: use [to_hex] for the exact
   bytes. *)
let to_utf8 s =
  if Stdlib.String.is_valid_utf_8 s then s
  else
    let buf = Buffer.create (String.length s + 8) in
    let rec go i =
      if i < String.length s then
        let d = Stdlib.String.get_utf_8_uchar s i in
        if Stdlib.Uchar.utf_decode_is_valid d then (
          let len = Stdlib.Uchar.utf_decode_length d in
          Buffer.add_substring buf s ~pos:i ~len ;
          go (i + len) )
        else (
          Stdlib.Buffer.add_utf_8_uchar buf
            (Stdlib.Uchar.of_int (Char.to_int s.[i])) ;
          go (i + 1) )
    in
    go 0 ; Buffer.contents buf

let to_hex s = Hex.encode s

let%test_module "arbitrary bytes" =
  ( module struct
    let%test "ASCII is unchanged" = String.equal (to_utf8 "MINA") "MINA"

    (* o1js writes symbols as UTF-8, e.g. "é" is c3 a9. *)
    let%test "valid UTF-8 is unchanged" =
      String.equal (to_utf8 "\xc3\xa9\xe2\x82\xac") "\xc3\xa9\xe2\x82\xac"

    (* Mainnet block 565083 sets the token symbol 0xff. *)
    let%test "a byte that is not UTF-8 becomes U+00XX" =
      String.equal (to_utf8 "\xff") "\xc3\xbf"

    let%test "valid sequences around an invalid byte are kept" =
      String.equal (to_utf8 "a\xffb\xc3\xa9\x80") "a\xc3\xbfb\xc3\xa9\xc2\x80"

    let%test "the result is always valid UTF-8" =
      Quickcheck.test (String.gen_with_length 6 Char.quickcheck_generator)
        ~f:(fun s -> assert (Stdlib.String.is_valid_utf_8 (to_utf8 s))) ;
      true

    let%test "hex keeps the exact bytes" =
      String.equal (to_hex "\xff") "ff" && String.equal (to_hex "") ""
  end )
