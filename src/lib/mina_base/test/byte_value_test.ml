(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- \
                  test '^any-byte values$'
    Subject:    Token symbols and zkApp URIs are any bytes, not necessarily
                UTF-8 (mainnet block 565083 set the token symbol "\xff"). JSON
                and bin_prot must carry them byte for byte.
 *)

open Core_kernel
open Mina_base

(* Each value can break a different layer: invalid UTF-8 (lone 0xff, a cut
   multi-byte sequence), NUL, escape syntax (backslash-x, quotes), and valid
   multi-byte UTF-8. A token symbol is at most 6 bytes. *)
let token_symbols =
  [ ""
  ; "MINA"
  ; "\xff"
  ; "a\xc3"
  ; "\x00"
  ; "a\x00b"
  ; "\x00\xfe"
  ; "\\x41"
  ; "'\"\\"
  ; "\xc3\xa9"
  ; "\xf0\x9f\xa6\x8a"
  ; "\x80\x9f\xc0\xf5\xfe\xff"
  ]

(* a zkApp URI is at most 255 bytes: 0x00..0xfe at once (0xff is above) *)
let zkapp_uris = token_symbols @ [ String.init 255 ~f:Char.of_int_exn ]

let check_json ~what ~to_yojson ~of_yojson value =
  let json = Yojson.Safe.to_string (to_yojson value) in
  match of_yojson (Yojson.Safe.from_string json) with
  | Ok decoded ->
      if not (String.equal value decoded) then
        failwithf "%s %S: JSON gave back %S" what value decoded ()
  | Error err ->
      failwithf "%s %S: JSON did not decode: %s" what value err ()

let check_bin_prot (type t) ~what (module M : Binable.S with type t = t)
    ~(to_string : t -> string) (value : t) =
  let decoded =
    Binable.of_string (module M) (Binable.to_string (module M) value)
  in
  if not (String.equal (to_string value) (to_string decoded)) then
    failwithf "%s %S: bin_prot gave back %S" what (to_string value)
      (to_string decoded) ()

let token_symbol_round_trips () =
  let open Account.Token_symbol in
  let check value =
    check_json ~what:"token symbol" ~to_yojson ~of_yojson value ;
    check_bin_prot ~what:"token symbol"
      (module Stable.Latest)
      ~to_string:Fn.id value
  in
  List.iter token_symbols ~f:check ;
  Quickcheck.test ~trials:100 ~seed:(`Deterministic "") gen ~f:check

let zkapp_uri_round_trips () =
  let open Zkapp_account.Zkapp_uri in
  let check value =
    check_json ~what:"zkApp URI" ~to_yojson ~of_yojson value ;
    check_bin_prot ~what:"zkApp URI"
      (module Stable.Latest)
      ~to_string:Fn.id value
  in
  List.iter zkapp_uris ~f:check ;
  Quickcheck.test ~trials:100 ~seed:(`Deterministic "") gen ~f:check
