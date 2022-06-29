(*
 * Copyright (c) 2014 Peter Zotov <whitequark@whitequark.org>
 * Copyright (c) 2015 David Sheets <sheets@alum.mit.edu>
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

let message = Bytes.of_string "The quick brown fox jumps over the lazy dog"

let test_digest ctxt =
  assert (Generichash.primitive = "blake2b") ;
  let hash = Generichash.Bytes.digest message in
  let hash' =
    "\001q\140\2365\205=ym\208\000 \224\191\236\180s\173#E}"
    ^ "\006;u\239\242\156\015\250.X\169"
  in
  assert_equal (Bytes.of_string hash') (Generichash.Bytes.of_hash hash) ;
  let hash = Generichash.(Bytes.digest ~size:size_min message) in
  let hash' = "$\157\249\164\159Q}\220\211\127\\\137v \236s" in
  assert_equal (Bytes.of_string hash') (Generichash.Bytes.of_hash hash) ;
  let hash = Generichash.(Bytes.digest ~size:size_max message) in
  let hash' =
    "\168\173\212\189\221\253\147\228\135}'F\230(\023\177"
    ^ "\0226J\031\167\188\020\141\149\t\011\1993;6s\248$\001"
    ^ "\207z\162\228\203\030\205\144)n?\020\203T\019\248\237"
    ^ "w\190s\004[\019\145L\220\214\169\024"
  in
  assert_equal (Bytes.of_string hash') (Generichash.Bytes.of_hash hash) ;

  let key = Generichash.Bytes.to_key (Bytes.of_string "SUPER SECRET KEY") in
  let hash = Generichash.Bytes.digest_with_key key message in
  let hash' =
    "\174m\018\173\1916\138\b`\227,\184QS\178 ZT\004\213\216"
    ^ "\171\227\152\ty\127\158\139\166\206\240"
  in
  assert_equal (Bytes.of_string hash') (Generichash.Bytes.of_hash hash) ;

  let key = Generichash.Bytes.to_key (Bytes.of_string "DUPER SECRET KEY") in
  let hash = Generichash.Bytes.digest_with_key key message in
  let hash' =
    "C\2120-\239R\003\243\233X\207M\187\242\244?\164\130\219"
    ^ ">\206QTR\031\230\188\252\167\027%\136"
  in
  assert_equal (Bytes.of_string hash') (Generichash.Bytes.of_hash hash)

let test_serialize ctxt =
  let hash = Generichash.Bytes.digest message in
  assert_equal (Generichash.Bytes.to_hash (Generichash.Bytes.of_hash hash)) hash ;
  assert_equal
    (Generichash.Bigbytes.to_hash (Generichash.Bigbytes.of_hash hash))
    hash

let test_equal ctxt =
  let size = Generichash.size_default in
  let h = Bytes.of_string (String.make size 'A') in
  let h' = Bytes.of_string ("B" ^ String.make (size - 1) 'A') in
  let h'' = Bytes.of_string (String.make (size - 1) 'A' ^ "B") in
  assert_bool "="
    ( 0
    = Generichash.compare
        (Generichash.Bytes.to_hash h)
        (Generichash.Bytes.to_hash h) ) ;
  assert_bool "<>"
    ( 0
    <> Generichash.compare
         (Generichash.Bytes.to_hash h)
         (Generichash.Bytes.to_hash h') ) ;
  assert_bool "<>"
    ( 0
    <> Generichash.compare
         (Generichash.Bytes.to_hash h)
         (Generichash.Bytes.to_hash h'') )

let test_exn ctxt =
  let too_small = Bytes.create (Generichash.size_min - 1) in
  assert_raises (Size_mismatch "Generichash.to_hash") (fun () ->
      Generichash.Bytes.to_hash too_small ) ;
  let too_big = Bytes.create (Generichash.size_max + 1) in
  assert_raises (Size_mismatch "Generichash.to_hash") (fun () ->
      Generichash.Bytes.to_hash too_big ) ;
  let too_small = Bytes.create (Generichash.key_size_min - 1) in
  assert_raises (Size_mismatch "Generichash.to_key") (fun () ->
      Generichash.Bytes.to_key too_small ) ;
  let too_big = Bytes.create (Generichash.key_size_max + 1) in
  assert_raises (Size_mismatch "Generichash.to_key") (fun () ->
      Generichash.Bytes.to_key too_big ) ;
  assert_raises (Size_mismatch "Generichash.init") (fun () ->
      Generichash.(init ~size:(size_min - 1) ()) ) ;
  assert_raises (Size_mismatch "Generichash.init") (fun () ->
      Generichash.(init ~size:(size_max + 1) ()) )

let test_streaming ctxt =
  let empty = Bytes.of_string "" in

  let direct_hash = Generichash.Bytes.digest empty in
  let state = Generichash.init () in
  let staged_hash = Generichash.final state in
  assert_bool "simple staged" (0 = Generichash.compare direct_hash staged_hash) ;

  let key = Generichash.Bytes.to_key (Bytes.of_string "SUPER SECRET KEY") in
  let direct_hash = Generichash.Bytes.digest_with_key key empty in
  let state = Generichash.init ~key () in
  let staged_hash = Generichash.final state in
  assert_bool "keyed staged" (0 = Generichash.compare direct_hash staged_hash) ;

  assert_raises (Already_finalized "Generichash.final") (fun () ->
      Generichash.final state ) ;

  assert_raises (Already_finalized "Generichash.update") (fun () ->
      Generichash.Bytes.update state (Bytes.of_string "lalala") ) ;

  let direct_hash = Generichash.(Bytes.digest ~size:size_max empty) in
  let state = Generichash.(init ~size:size_max ()) in
  let staged_hash = Generichash.final state in
  assert_bool "size_max staged" (0 = Generichash.compare direct_hash staged_hash) ;

  let direct_hash = Generichash.(Bytes.digest message) in
  let state = Generichash.init () in
  let () = Generichash.Bytes.update state message in
  let staged_hash = Generichash.final state in
  assert_bool "message staged" (0 = Generichash.compare direct_hash staged_hash) ;

  let hstate = Generichash.init () in
  let hello = Bytes.of_string "hello" in
  let () = Generichash.Bytes.update hstate hello in
  let hwstate = Generichash.copy hstate in
  let world = Bytes.of_string " world" in
  let hello_world = Bytes.cat hello world in
  let () = Generichash.Bytes.update hwstate world in
  let h = Generichash.final hstate in
  let hw = Generichash.final hwstate in
  assert_bool "copy stream 1"
    (0 = Generichash.compare (Generichash.Bytes.digest hello) h) ;
  assert_bool "copy stream 2"
    (0 = Generichash.compare (Generichash.Bytes.digest hello_world) hw)

let suite =
  "Generichash"
  >::: [ "test_digest" >:: test_digest
       ; "test_serialize" >:: test_serialize
       ; "test_equal" >:: test_equal
       ; "test_exn" >:: test_exn
       ; "test_streaming" >:: test_streaming
       ]
