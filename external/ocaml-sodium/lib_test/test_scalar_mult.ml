(* Derived from:
 * https://chromium.googlesource.com/experimental/chromium/src/+/lkgr/crypto/curve25519_unittest.cc
 *
 * Original license:
 *
 * Copyright 2014 The Chromium Authors. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *    * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *    * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *    * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *)

open OUnit2
open Sodium

(* Test that the basic shared key exchange identity holds: that both parties end
   up with the same shared key. This test starts with a fixed private key for
   two parties: alice and bob. Runs ScalarBaseMult and ScalarMult to compute
   public key and shared key for alice and bob. It asserts that alice and bob
   have the same shared key. *)
let test_scalarmult ctxt =
  assert (Scalar_mult.primitive = "curve25519");

  let sk  = "\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"^
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"^
            "\x00\x00\x00\x00\x00\x00\x00\x00" in
  let sk  = Scalar_mult.Bytes.to_integer (Bytes.of_string sk) in
  let sk' = "\x05\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"^
            "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"^
            "\x00\x00\x00\x00\x00\x00\x00\x00" in
  let sk' = Scalar_mult.Bytes.to_integer (Bytes.of_string sk') in
  (* Get public key for alice and bob. *)
  let pk  = Scalar_mult.base sk  in
  let pk' = Scalar_mult.base sk' in
  (* Get the shared key for alice, by using alice's private key and bob's
     public key. *)
  let ck  = Scalar_mult.mult sk' pk in
  (* Get the shared key for bob, by using bob's private key and alice's public
     key. *)
  let ck' = Scalar_mult.mult sk pk' in
  (* Computed shared key of alice and bob should be the same. *)
  assert_equal ~printer:(fun g -> Printf.sprintf "%S"
                         (Bytes.to_string (Scalar_mult.Bytes.of_group_elt g))) ck ck';
  ()

let test_permute ctxt =
  assert_raises (Size_mismatch "Scalar_mult.to_integer")
                (fun () -> Scalar_mult.Bytes.to_integer (Bytes.of_string "\x03"));
  assert_raises (Size_mismatch "Scalar_mult.to_group_elt")
                (fun () -> Scalar_mult.Bytes.to_group_elt (Bytes.of_string "\x03"))

let test_equal ctxt =
  let sk   = Bytes.of_string (String.make (Scalar_mult.integer_size) 'A') in
  let sk'  = Bytes.of_string ("B" ^ (String.make (Scalar_mult.integer_size - 1) 'A')) in
  let sk'' = Bytes.of_string ((String.make (Scalar_mult.integer_size - 1) 'A') ^ "B") in
  assert_bool "=" (Scalar_mult.equal_integer (Scalar_mult.Bytes.to_integer sk)
                                            (Scalar_mult.Bytes.to_integer sk));
  assert_bool "<>" (not (Scalar_mult.equal_integer (Scalar_mult.Bytes.to_integer sk)
                                                  (Scalar_mult.Bytes.to_integer sk')));
  assert_bool "<>" (not (Scalar_mult.equal_integer (Scalar_mult.Bytes.to_integer sk)
                                                  (Scalar_mult.Bytes.to_integer sk'')));
  let pk   = Bytes.of_string (String.make (Scalar_mult.group_elt_size) 'A') in
  let pk'  = Bytes.of_string ("B" ^ (String.make (Scalar_mult.group_elt_size - 1) 'A')) in
  let pk'' = Bytes.of_string ((String.make (Scalar_mult.group_elt_size - 1) 'A') ^ "B") in
  assert_bool "=" (Scalar_mult.equal_group_elt (Scalar_mult.Bytes.to_group_elt pk)
                                              (Scalar_mult.Bytes.to_group_elt pk));
  assert_bool "<>" (not (Scalar_mult.equal_group_elt (Scalar_mult.Bytes.to_group_elt pk)
                                                    (Scalar_mult.Bytes.to_group_elt pk')));
  assert_bool "<>" (not (Scalar_mult.equal_group_elt (Scalar_mult.Bytes.to_group_elt pk)
                                                    (Scalar_mult.Bytes.to_group_elt pk'')))

let suite = "Scalarmult" >::: [
    "test_scalarmult" >:: test_scalarmult;
    "test_permute"    >:: test_permute;
    "test_equal"      >:: test_equal;
  ]
