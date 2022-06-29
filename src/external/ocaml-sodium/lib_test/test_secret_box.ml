(*
 * Copyright (c) 2014 Peter Zotov <whitequark@whitequark.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

open OUnit2
open Sodium

let add_byte b = Bytes.concat (Bytes.of_string "") [ b; Bytes.of_string "\x00" ]

let test_equal_keys ctxt =
  let sk = Bytes.of_string (String.make Secret_box.key_size 'A') in
  let sk' = Bytes.of_string ("B" ^ String.make (Secret_box.key_size - 1) 'A') in
  let sk'' =
    Bytes.of_string (String.make (Secret_box.key_size - 1) 'A' ^ "B")
  in
  assert_bool "="
    (Secret_box.equal_keys
       (Secret_box.Bytes.to_key sk)
       (Secret_box.Bytes.to_key sk) ) ;
  assert_bool "<>"
    (not
       (Secret_box.equal_keys
          (Secret_box.Bytes.to_key sk)
          (Secret_box.Bytes.to_key sk') ) ) ;
  assert_bool "<>"
    (not
       (Secret_box.equal_keys
          (Secret_box.Bytes.to_key sk)
          (Secret_box.Bytes.to_key sk'') ) )

let test_permute ctxt =
  let k = Secret_box.random_key () in
  assert_raises (Size_mismatch "Secret_box.to_key") (fun () ->
      Secret_box.Bytes.to_key (add_byte (Secret_box.Bytes.of_key k)) )

let test_nonce_operations ctxt =
  let n = Bytes.of_string (String.make Secret_box.nonce_size '\x00') in
  let n' =
    Bytes.of_string (String.make (Secret_box.nonce_size - 1) '\x00' ^ "\x01")
  in
  let n'' =
    Bytes.of_string (String.make (Secret_box.nonce_size - 1) '\x00' ^ "\x02")
  in
  let n''' =
    Bytes.of_string
      (String.make (Secret_box.nonce_size - 3) '\x00' ^ "\x02\x00\x00")
  in
  let n'''' = Bytes.of_string (String.make Secret_box.nonce_size '\xff') in
  assert_bool "=" (Secret_box.nonce_of_bytes n = Secret_box.nonce_of_bytes n) ;
  assert_bool "<>" (Secret_box.nonce_of_bytes n <> Secret_box.nonce_of_bytes n') ;
  assert_raises (Sodium.Size_mismatch "Secret_box.nonce_of_bytes") (fun () ->
      Secret_box.nonce_of_bytes (add_byte n) ) ;
  assert_equal
    (Secret_box.nonce_of_bytes n')
    (Secret_box.increment_nonce (Secret_box.nonce_of_bytes n)) ;
  assert_equal
    (Secret_box.nonce_of_bytes n'')
    (Secret_box.increment_nonce ~step:2 (Secret_box.nonce_of_bytes n)) ;
  assert_equal
    (Secret_box.nonce_of_bytes n''')
    (Secret_box.increment_nonce ~step:0x20000 (Secret_box.nonce_of_bytes n)) ;
  assert_equal
    (Secret_box.nonce_of_bytes n'''')
    (Secret_box.increment_nonce ~step:(-1) (Secret_box.nonce_of_bytes n))

let setup () =
  ( Secret_box.random_key ()
  , Bytes.of_string "wild wild fox"
  , Secret_box.random_nonce () )

let test_secret_box ctxt =
  let k, msg, nonce = setup () in
  let cmsg = Secret_box.Bytes.secret_box k msg nonce in
  let msg' = Secret_box.Bytes.secret_box_open k cmsg nonce in
  assert_equal msg msg'

let test_secret_box_fail_permute ctxt =
  let k, msg, nonce = setup () in
  let cmsg = Secret_box.Bytes.secret_box k msg nonce in
  Bytes.set cmsg 10 'a' ;
  assert_raises Verification_failure (fun () ->
      ignore (Secret_box.Bytes.secret_box_open k cmsg nonce) )

let test_secret_box_fail_key ctxt =
  let k, msg, nonce = setup () in
  let k' = Secret_box.random_key () in
  let cmsg = Secret_box.Bytes.secret_box k msg nonce in
  assert_raises Verification_failure (fun () ->
      ignore (Secret_box.Bytes.secret_box_open k' cmsg nonce) )

let suite =
  "Secret_box"
  >::: [ "test_equal_keys" >:: test_equal_keys
       ; "test_nonce_operations" >:: test_nonce_operations
       ; "test_permute" >:: test_permute
       ; "test_secret_box" >:: test_secret_box
       ; "test_secret_box_fail_permute" >:: test_secret_box_fail_permute
       ; "test_secret_box_fail_key" >:: test_secret_box_fail_key
       ]
