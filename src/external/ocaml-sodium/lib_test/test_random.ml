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

let test_stir ctxt = Sodium.Random.stir ()

let test_generate ctxt =
  let rnd = Sodium.Random.Bytes.generate 42 in
  assert_equal ~printer:string_of_int 42 (Bytes.length rnd) ;

  let rnd = Sodium.Random.Bigbytes.generate 42 in
  assert_equal ~printer:string_of_int 42 (Bigarray.Array1.dim rnd)

let test_generate_into ctxt =
  let str = Bytes.of_string "AAAABBBB" in
  Sodium.Random.Bytes.generate_into str ;
  assert_bool "changes contents" (Bytes.of_string "AAAABBBB" <> str) ;

  let arr = Bigarray.(Array1.create char c_layout 10) in
  Bigarray.Array1.fill arr 'A' ;
  let arr' = Bigarray.(Array1.create char c_layout 10) in
  Bigarray.Array1.blit arr arr' ;
  Sodium.Random.Bigbytes.generate_into arr' ;
  assert_bool "changes contents" (arr <> arr')

let suite =
  "Random"
  >::: [ "test_stir" >:: test_stir
       ; "test_generate" >:: test_generate
       ; "test_generate_into" >:: test_generate_into
       ]
