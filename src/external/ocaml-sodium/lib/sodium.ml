(*
 * Copyright (c) 2013-2015 David Sheets <sheets@alum.mit.edu>
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

open Ctypes
open Unsigned
module Static = Ctypes_static

exception Verification_failure

exception Size_mismatch of string

exception Already_finalized of string

type public

type secret

type channel

module Storage = Sodium_storage

type bigbytes = Storage.bigbytes

module C = Sodium_bindings.C (Sodium_generated)
module Type = Sodium_types.C (Sodium_types_detected)
module Sodium_bytes = C.Make (Storage.Bytes)

let wipe str =
  Sodium_bytes.memzero (Storage.Bytes.to_ptr str) (Storage.Bytes.len_size_t str)

let memcpy ~dest ~src typ =
  let size = sizeof typ in
  let cast p = from_voidp (array size uchar) (to_voidp p) in
  cast dest <-@ !@(cast src)

let increment_be_bytes ?(step = 1) b =
  let b = Bytes.copy b in
  let rec incr_byte step byteno =
    let res = Char.code (Bytes.get b byteno) + step in
    let lo, hi = (res land 0xff, res asr 8) in
    Bytes.set b byteno (Char.chr lo) ;
    if hi = 0 || byteno = 0 then () else incr_byte hi (byteno - 1)
  in
  incr_byte step (Bytes.length b - 1) ;
  b

module Verify = struct
  module C = C.Verify

  let equal_fn size =
    match size with
    | 16 ->
        fun a b ->
          C.verify_16 (Storage.Bytes.to_ptr a) (Storage.Bytes.to_ptr b) = 0
    | 32 ->
        fun a b ->
          C.verify_32 (Storage.Bytes.to_ptr a) (Storage.Bytes.to_ptr b) = 0
    | 64 ->
        fun a b ->
          C.verify_64 (Storage.Bytes.to_ptr a) (Storage.Bytes.to_ptr b) = 0
    | _ ->
        assert false
end

module Random = struct
  module C = C.Random

  let stir = C.stir

  module type S = sig
    type storage

    val generate_into : storage -> unit

    val generate : int -> storage
  end

  module Make (T : Storage.S) = struct
    module C = C.Make (T)

    type storage = T.t

    let generate_into str = C.gen (T.to_ptr str) (T.len_size_t str)

    let generate size =
      let str = T.create size in
      generate_into str ; str
  end

  module Bytes = Make (Storage.Bytes)
  module Bigbytes = Make (Storage.Bigbytes)
end

module Box = struct
  module C = C.Box

  let primitive = C.primitive

  let public_key_size = Size_t.to_int (C.publickeybytes ())

  let secret_key_size = Size_t.to_int (C.secretkeybytes ())

  let channel_key_size = Size_t.to_int (C.beforenmbytes ())

  let nonce_size = Size_t.to_int (C.noncebytes ())

  let zero_size = Size_t.to_int (C.zerobytes ())

  let box_zero_size = Size_t.to_int (C.boxzerobytes ())

  (* Invariant: a key is {public,secret,channel}_key_size bytes long. *)
  type 'a key = Bytes.t

  type secret_key = secret key

  type public_key = public key

  type channel_key = channel key

  type keypair = secret key * public key

  (* Invariant: a nonce is nonce_size bytes long. *)
  type nonce = Bytes.t

  let random_keypair () =
    let pk, sk =
      ( Storage.Bytes.create public_key_size
      , Storage.Bytes.create secret_key_size )
    in
    let ret =
      C.box_keypair (Storage.Bytes.to_ptr pk) (Storage.Bytes.to_ptr sk)
    in
    assert (ret = 0) ;
    (* always returns 0 *)
    (sk, pk)

  let random_nonce () = Random.Bytes.generate nonce_size

  let wipe_key = wipe

  let equal_public_keys = Verify.equal_fn public_key_size

  let equal_secret_keys = Verify.equal_fn secret_key_size

  let equal_channel_keys = Verify.equal_fn channel_key_size

  let compare_public_keys = Bytes.compare

  let nonce_of_bytes b =
    if Bytes.length b <> nonce_size then
      raise (Size_mismatch "Box.nonce_of_bytes") ;
    b

  let increment_nonce = increment_be_bytes

  let precompute skey pkey =
    let params = Storage.Bytes.create channel_key_size in
    let ret =
      C.box_beforenm
        (Storage.Bytes.to_ptr params)
        (Storage.Bytes.to_ptr pkey)
        (Storage.Bytes.to_ptr skey)
    in
    assert (ret = 0) ;
    (* always returns 0 *)
    params

  module type S = sig
    type storage

    val of_public_key : public key -> storage

    val to_public_key : storage -> public key

    val of_secret_key : secret key -> storage

    val to_secret_key : storage -> secret key

    val of_channel_key : channel key -> storage

    val to_channel_key : storage -> channel key

    val of_nonce : nonce -> storage

    val to_nonce : storage -> nonce

    val box : secret key -> public key -> storage -> nonce -> storage

    val box_open : secret key -> public key -> storage -> nonce -> storage

    val fast_box : channel key -> storage -> nonce -> storage

    val fast_box_open : channel key -> storage -> nonce -> storage
  end

  module Make (T : Storage.S) = struct
    module C = C.Make (T)

    type storage = T.t

    let verify_length str len fn_name =
      if T.length str <> len then raise (Size_mismatch fn_name)

    let of_public_key key = T.of_bytes key

    let to_public_key str =
      verify_length str public_key_size "Box.to_public_key" ;
      T.to_bytes str

    let of_secret_key key = T.of_bytes key

    let to_secret_key str =
      verify_length str secret_key_size "Box.to_secret_key" ;
      T.to_bytes str

    let of_channel_key key = T.of_bytes key

    let to_channel_key str =
      verify_length str channel_key_size "Box.to_channel_key" ;
      T.to_bytes str

    let of_nonce nonce = T.of_bytes nonce

    let to_nonce str =
      verify_length str nonce_size "Box.to_nonce" ;
      T.to_bytes str

    let pad a apad bpad f =
      let a' = T.create (apad + T.length a) in
      let b' = T.create (T.length a') in
      T.zero a' 0 apad ;
      T.blit a 0 a' apad (T.length a) ;
      f a' b' ;
      T.sub b' bpad (T.length b' - bpad)

    let box skey pkey message nonce =
      pad message zero_size box_zero_size (fun cleartext ciphertext ->
          let ret =
            C.box (T.to_ptr ciphertext) (T.to_ptr cleartext)
              (T.len_ullong cleartext)
              (Storage.Bytes.to_ptr nonce)
              (Storage.Bytes.to_ptr pkey)
              (Storage.Bytes.to_ptr skey)
          in
          assert (ret = 0)
          (* always returns 0 *) )

    let box_open skey pkey ciphertext nonce =
      pad ciphertext box_zero_size zero_size (fun ciphertext cleartext ->
          let ret =
            C.box_open (T.to_ptr cleartext) (T.to_ptr ciphertext)
              (T.len_ullong ciphertext)
              (Storage.Bytes.to_ptr nonce)
              (Storage.Bytes.to_ptr pkey)
              (Storage.Bytes.to_ptr skey)
          in
          if ret <> 0 then raise Verification_failure )

    let fast_box params message nonce =
      pad message zero_size box_zero_size (fun cleartext ciphertext ->
          let ret =
            C.box_afternm (T.to_ptr ciphertext) (T.to_ptr cleartext)
              (T.len_ullong cleartext)
              (Storage.Bytes.to_ptr nonce)
              (Storage.Bytes.to_ptr params)
          in
          assert (ret = 0)
          (* always returns 0 *) )

    let fast_box_open params ciphertext nonce =
      pad ciphertext box_zero_size zero_size (fun ciphertext cleartext ->
          let ret =
            C.box_open_afternm (T.to_ptr cleartext) (T.to_ptr ciphertext)
              (T.len_ullong ciphertext)
              (Storage.Bytes.to_ptr nonce)
              (Storage.Bytes.to_ptr params)
          in
          if ret <> 0 then raise Verification_failure )
  end

  module Bytes = Make (Storage.Bytes)
  module Bigbytes = Make (Storage.Bigbytes)
end

module Sign = struct
  module C = C.Sign

  let primitive = C.primitive

  let public_key_size = Size_t.to_int (C.publickeybytes ())

  let secret_key_size = Size_t.to_int (C.secretkeybytes ())

  let reserved_size = Size_t.to_int (C.bytes ())

  let signature_size = Size_t.to_int (C.bytes ())

  let seed_size = Size_t.to_int (C.seedbytes ())

  (* Invariant: a key is {public,secret}_key_size bytes long. *)
  type 'a key = Bytes.t

  type secret_key = secret key

  type public_key = public key

  type keypair = secret key * public key

  (* Invariant: a signature is signature_size bytes long. *)
  type signature = Bytes.t

  (* Invariant: a seed is seed_size bytes long. *)
  type seed = Bytes.t

  let random_keypair () =
    let pk, sk =
      ( Storage.Bytes.create public_key_size
      , Storage.Bytes.create secret_key_size )
    in
    let ret =
      C.sign_keypair (Storage.Bytes.to_ptr pk) (Storage.Bytes.to_ptr sk)
    in
    assert (ret = 0) ;
    (* always returns 0 *)
    (sk, pk)

  let seed_keypair seed =
    let pk, sk =
      ( Storage.Bytes.create public_key_size
      , Storage.Bytes.create secret_key_size )
    in
    let ret =
      C.sign_seed_keypair (Storage.Bytes.to_ptr pk) (Storage.Bytes.to_ptr sk)
        (Storage.Bytes.to_ptr seed)
    in
    assert (ret = 0) ;
    (sk, pk)

  let secret_key_to_seed sk =
    let seed = Storage.Bytes.create seed_size in
    let ret =
      C.sign_sk_to_seed (Storage.Bytes.to_ptr seed) (Storage.Bytes.to_ptr sk)
    in
    assert (ret = 0) ;
    seed

  let secret_key_to_public_key sk =
    let pk = Storage.Bytes.create public_key_size in
    let ret =
      C.sign_sk_to_pk (Storage.Bytes.to_ptr pk) (Storage.Bytes.to_ptr sk)
    in
    assert (ret = 0) ;
    pk

  let wipe_key = wipe

  let equal_public_keys = Verify.equal_fn public_key_size

  let equal_secret_keys = Verify.equal_fn secret_key_size

  let compare_public_keys = Bytes.compare

  let box_public_key pk =
    let pk' = Bytes.create Box.public_key_size in
    let ret =
      C.sign_pk_to_curve25519 (Storage.Bytes.to_ptr pk')
        (Storage.Bytes.to_ptr pk)
    in
    assert (ret = 0) ;
    pk'

  let box_secret_key sk =
    let sk' = Bytes.create Box.secret_key_size in
    let ret =
      C.sign_sk_to_curve25519 (Storage.Bytes.to_ptr sk')
        (Storage.Bytes.to_ptr sk)
    in
    assert (ret = 0) ;
    sk'

  let box_keypair (sk, pk) = (box_secret_key sk, box_public_key pk)

  module type S = sig
    type storage

    val of_public_key : public key -> storage

    val to_public_key : storage -> public key

    val of_secret_key : secret key -> storage

    val to_secret_key : storage -> secret key

    val of_signature : signature -> storage

    val to_signature : storage -> signature

    val of_seed : seed -> storage

    val to_seed : storage -> seed

    val sign : secret key -> storage -> storage

    val sign_open : public key -> storage -> storage

    val sign_detached : secret key -> storage -> signature

    val verify : public key -> signature -> storage -> unit
  end

  module Make (T : Storage.S) = struct
    module C = C.Make (T)

    type storage = T.t

    let verify_length str len fn_name =
      if T.length str <> len then raise (Size_mismatch fn_name)

    let of_public_key key = T.of_bytes key

    let to_public_key str =
      verify_length str public_key_size "Sign.to_public_key" ;
      T.to_bytes str

    let of_secret_key key = T.of_bytes key

    let to_secret_key str =
      verify_length str secret_key_size "Sign.to_secret_key" ;
      T.to_bytes str

    let of_signature sign = T.of_bytes sign

    let to_signature str =
      verify_length str signature_size "Sign.to_signature" ;
      T.to_bytes str

    let of_seed seed = T.of_bytes seed

    let to_seed str =
      verify_length str seed_size "Sign.to_seed" ;
      T.to_bytes str

    let sign skey message =
      let signed_msg = T.create (T.length message + reserved_size) in
      let signed_len = allocate ullong (Unsigned.ULLong.of_int 0) in
      let ret =
        C.sign (T.to_ptr signed_msg) signed_len (T.to_ptr message)
          (T.len_ullong message)
          (Storage.Bytes.to_ptr skey)
      in
      assert (ret = 0) ;
      (* always returns 0 *)
      T.sub signed_msg 0 (Unsigned.ULLong.to_int !@signed_len)

    let sign_open pkey signed_msg =
      let message = T.create (T.length signed_msg) in
      let msg_len = allocate ullong (Unsigned.ULLong.of_int 0) in
      let ret =
        C.sign_open (T.to_ptr message) msg_len (T.to_ptr signed_msg)
          (T.len_ullong signed_msg)
          (Storage.Bytes.to_ptr pkey)
      in
      if ret <> 0 then raise Verification_failure ;
      T.sub message 0 (Unsigned.ULLong.to_int !@msg_len)

    let sign_detached skey message =
      let signature = T.create signature_size in
      let ret =
        C.sign_detached (T.to_ptr signature) None (T.to_ptr message)
          (T.len_ullong message)
          (Storage.Bytes.to_ptr skey)
      in
      assert (ret = 0) ;
      (* always returns 0 *)
      T.to_bytes signature

    let verify pkey (signature : signature) message =
      let ret =
        C.sign_verify
          (Storage.Bytes.to_ptr signature)
          (T.to_ptr message) (T.len_ullong message)
          (Storage.Bytes.to_ptr pkey)
      in
      if ret <> 0 then raise Verification_failure
  end

  module Bytes = Make (Storage.Bytes)
  module Bigbytes = Make (Storage.Bigbytes)
end

module Scalar_mult = struct
  module C = C.Scalar_mult

  let primitive = C.primitive

  let group_elt_size = Size_t.to_int (C.bytes ())

  let integer_size = Size_t.to_int (C.scalarbytes ())

  (* Invariant: a group element is group_elt_size bytes long. *)
  type group_elt = Bytes.t

  (* Invariant: an integer is integer_size bytes long. *)
  type integer = Bytes.t

  let equal_group_elt = Verify.equal_fn group_elt_size

  let equal_integer = Verify.equal_fn integer_size

  let mult scalar elem =
    let elem' = Storage.Bytes.create group_elt_size in
    let ret =
      Storage.Bytes.(C.scalarmult (to_ptr elem') (to_ptr scalar) (to_ptr elem))
    in
    assert (ret = 0) ;
    (* always returns 0 *)
    elem'

  let base scalar =
    let elem = Storage.Bytes.create group_elt_size in
    let ret = Storage.Bytes.(C.scalarmult_base (to_ptr elem) (to_ptr scalar)) in
    assert (ret = 0) ;
    (* always returns 0 *)
    elem

  module type S = sig
    type storage

    val of_group_elt : group_elt -> storage

    val to_group_elt : storage -> group_elt

    val of_integer : integer -> storage

    val to_integer : storage -> integer
  end

  module Make (T : Storage.S) = struct
    type storage = T.t

    let of_group_elt str = T.of_bytes str

    let to_group_elt str =
      if T.length str <> group_elt_size then
        raise (Size_mismatch "Scalar_mult.to_group_elt") ;
      T.to_bytes str

    let of_integer str = T.of_bytes str

    let to_integer str =
      if T.length str <> integer_size then
        raise (Size_mismatch "Scalar_mult.to_integer") ;
      T.to_bytes str
  end

  module Bytes = Make (Storage.Bytes)
  module Bigbytes = Make (Storage.Bigbytes)
end

module Password_hash = struct
  module Sodium = C
  module C = C.Password_hash

  let primitive = C.primitive

  let salt_size = Size_t.to_int (C.saltbytes ())

  let password_hash_size = Size_t.to_int (C.strbytes ())

  (* Invariant: a salt is salt_size bytes long. *)
  type salt = Bytes.t

  type password = Bytes.t

  type difficulty = { mem_limit : int64; ops_limit : int }

  let interactive =
    let mem_limit = Size_t.to_int64 (C.memlimit_interactive ()) in
    let ops_limit = C.opslimit_interactive () in
    { mem_limit; ops_limit }

  let moderate =
    let mem_limit = Size_t.to_int64 (C.memlimit_moderate ()) in
    let ops_limit = C.opslimit_moderate () in
    { mem_limit; ops_limit }

  let sensitive =
    let mem_limit = Size_t.to_int64 (C.memlimit_sensitive ()) in
    let ops_limit = C.opslimit_sensitive () in
    { mem_limit; ops_limit }

  let wipe_password = wipe

  let random_salt () = Random.Bytes.generate salt_size

  let salt_of_bytes b =
    if Bytes.length b <> salt_size then
      raise (Size_mismatch "Password_hash.salt_of_bytes") ;
    b

  let derive_key key_size { ops_limit; mem_limit } pw salt =
    let key = Bytes.create key_size in
    let ret =
      C.derive (Storage.Bytes.to_ptr key) (ULLong.of_int key_size)
        (Storage.Bytes.to_ptr pw)
        (Storage.Bytes.len_ullong pw)
        (Storage.Bytes.to_ptr salt)
        (ULLong.of_int ops_limit)
        (Size_t.of_int64 mem_limit)
        (C.alg ())
    in
    assert (ret = 0) ;
    (* always returns 0 *)
    key

  module type S = sig
    type storage

    val of_salt : salt -> storage

    val to_salt : storage -> salt

    val wipe_to_password : storage -> password

    val hash_password : difficulty -> password -> storage

    val verify_password_hash : storage -> password -> bool
  end

  module Make (T : Storage.S) = struct
    module C = C.Make (T)
    module Sodium = Sodium.Make (T)

    type storage = T.t

    let of_salt salt = T.of_bytes salt

    let to_salt str =
      if T.length str <> salt_size then
        raise (Size_mismatch "Password_hash.to_salt") ;
      T.to_bytes str

    let wipe_to_password str =
      let res = T.to_bytes str in
      Sodium.memzero (T.to_ptr str) (T.len_size_t str) ;
      res

    let hash_password { ops_limit; mem_limit } pw =
      let str = T.create password_hash_size in
      let ret =
        C.hash (T.to_ptr str) (Storage.Bytes.to_ptr pw)
          (Storage.Bytes.len_ullong pw)
          (ULLong.of_int ops_limit)
          (Size_t.of_int64 mem_limit)
      in
      assert (ret = 0) ;
      (* always returns 0 *)
      str

    let verify_password_hash str pw =
      let ret =
        C.verify (T.to_ptr str) (Storage.Bytes.to_ptr pw)
          (Storage.Bytes.len_ullong pw)
      in
      ret = 0
  end

  module Bytes = Make (Storage.Bytes)
  module Bigbytes = Make (Storage.Bigbytes)
end

module Secret_box = struct
  module C = C.Secret_box

  let primitive = C.primitive

  let key_size = Size_t.to_int (C.keybytes ())

  let nonce_size = Size_t.to_int (C.noncebytes ())

  let zero_size = Size_t.to_int (C.zerobytes ())

  let box_zero_size = Size_t.to_int (C.boxzerobytes ())

  (* Invariant: a key is key_size bytes long. *)
  type 'a key = Bytes.t

  type secret_key = secret key

  (* Invariant: a nonce is nonce_size bytes long. *)
  type nonce = Bytes.t

  let random_key () = Random.Bytes.generate key_size

  let derive_key = Password_hash.derive_key key_size

  let random_nonce =
    if nonce_size > 8 then fun () -> Random.Bytes.generate nonce_size
    else fun () ->
      raise (Failure "Randomly generated nonces 8 bytes long or less are unsafe")

  let nonce_of_bytes b =
    if Bytes.length b <> nonce_size then
      raise (Size_mismatch "Secret_box.nonce_of_bytes") ;
    b

  let increment_nonce = increment_be_bytes

  let wipe_key = wipe

  let equal_keys = Verify.equal_fn key_size

  module type S = sig
    type storage

    val of_key : secret key -> storage

    val to_key : storage -> secret key

    val of_nonce : nonce -> storage

    val to_nonce : storage -> nonce

    val secret_box : secret key -> storage -> nonce -> storage

    val secret_box_open : secret key -> storage -> nonce -> storage
  end

  module Make (T : Storage.S) = struct
    module C = C.Make (T)

    type storage = T.t

    let verify_length str len fn_name =
      if T.length str <> len then raise (Size_mismatch fn_name)

    let of_key key = T.of_bytes key

    let to_key str =
      verify_length str key_size "Secret_box.to_key" ;
      T.to_bytes str

    let of_nonce nonce = T.of_bytes nonce

    let to_nonce str =
      verify_length str nonce_size "Secret_box.to_nonce" ;
      T.to_bytes str

    let pad a apad bpad f =
      let a' = T.create (apad + T.length a) in
      let b' = T.create (T.length a') in
      T.zero a' 0 apad ;
      T.blit a 0 a' apad (T.length a) ;
      f a' b' ;
      T.sub b' bpad (T.length b' - bpad)

    let secret_box key message nonce =
      pad message zero_size box_zero_size (fun cleartext ciphertext ->
          let ret =
            C.secretbox (T.to_ptr ciphertext) (T.to_ptr cleartext)
              (T.len_ullong cleartext)
              (Storage.Bytes.to_ptr nonce)
              (Storage.Bytes.to_ptr key)
          in
          assert (ret = 0)
          (* always returns 0 *) )

    let secret_box_open key ciphertext nonce =
      pad ciphertext box_zero_size zero_size (fun ciphertext cleartext ->
          let ret =
            C.secretbox_open (T.to_ptr cleartext) (T.to_ptr ciphertext)
              (T.len_ullong ciphertext)
              (Storage.Bytes.to_ptr nonce)
              (Storage.Bytes.to_ptr key)
          in
          if ret <> 0 then raise Verification_failure )
  end

  module Bytes = Make (Storage.Bytes)
  module Bigbytes = Make (Storage.Bigbytes)
end

module Stream = struct
  module C = C.Stream

  let primitive = C.primitive

  let key_size = Size_t.to_int (C.keybytes ())

  let nonce_size = Size_t.to_int (C.noncebytes ())

  (* Invariant: a key is key_size bytes long. *)
  type 'a key = Bytes.t

  type secret_key = secret key

  (* Invariant: a nonce is nonce_size bytes long. *)
  type nonce = Bytes.t

  let random_key () = Random.Bytes.generate key_size

  let derive_key = Password_hash.derive_key key_size

  let random_nonce =
    if nonce_size > 8 then fun () -> Random.Bytes.generate nonce_size
    else fun () ->
      raise (Failure "Randomly generated nonces 8 bytes long or less are unsafe")

  let nonce_of_bytes b =
    if Bytes.length b <> nonce_size then
      raise (Size_mismatch "Stream.nonce_of_bytes") ;
    b

  let increment_nonce = increment_be_bytes

  let wipe_key = wipe

  let equal_keys = Verify.equal_fn key_size

  module type S = sig
    type storage

    val of_key : secret key -> storage

    val to_key : storage -> secret key

    val of_nonce : nonce -> storage

    val to_nonce : storage -> nonce

    val stream : secret key -> int -> nonce -> storage

    val stream_xor : secret key -> storage -> nonce -> storage
  end

  module Make (T : Storage.S) = struct
    module C = C.Make (T)

    type storage = T.t

    let verify_length str len fn_name =
      if T.length str <> len then raise (Size_mismatch fn_name)

    let of_key key = T.of_bytes key

    let to_key str =
      verify_length str key_size "Stream.to_key" ;
      T.to_bytes str

    let of_nonce nonce = T.of_bytes nonce

    let to_nonce str =
      verify_length str nonce_size "Stream.to_nonce" ;
      T.to_bytes str

    let stream key len nonce =
      let stream = T.create len in
      let ret =
        C.stream (T.to_ptr stream) (T.len_ullong stream)
          (Storage.Bytes.to_ptr nonce)
          (Storage.Bytes.to_ptr key)
      in
      assert (ret = 0) ;
      (* always returns 0 *)
      stream

    let stream_xor key message nonce =
      let ciphertext = T.create (T.length message) in
      let ret =
        C.stream_xor (T.to_ptr ciphertext) (T.to_ptr message)
          (T.len_ullong message)
          (Storage.Bytes.to_ptr nonce)
          (Storage.Bytes.to_ptr key)
      in
      assert (ret = 0) ;
      (* always returns 0 *)
      ciphertext
  end

  module Bytes = Make (Storage.Bytes)
  module Bigbytes = Make (Storage.Bigbytes)
end

module Gen_auth (M : sig
  val scope : string

  val primitive : string

  val name : string
end) =
struct
  module C = C.Gen_auth (M)

  let primitive = M.primitive

  let key_size = Size_t.to_int (C.keybytes ())

  let auth_size = Size_t.to_int (C.bytes ())

  (* Invariant: a key is key_size bytes long. *)
  type 'a key = Bytes.t

  type secret_key = secret key

  (* Invariant: an auth is auth_size bytes long. *)
  type auth = Bytes.t

  let random_key () = Random.Bytes.generate key_size

  let derive_key = Password_hash.derive_key key_size

  let wipe_key = wipe

  let equal_keys = Verify.equal_fn key_size

  module type S = sig
    type storage

    val of_key : secret key -> storage

    val to_key : storage -> secret key

    val of_auth : auth -> storage

    val to_auth : storage -> auth

    val auth : secret key -> storage -> auth

    val verify : secret key -> auth -> storage -> unit
  end

  module Make (T : Storage.S) = struct
    module C = C.Make (T)

    type storage = T.t

    let verify_length str len fn_name =
      if T.length str <> len then raise (Size_mismatch fn_name)

    let of_key key = T.of_bytes key

    let to_key =
      let fn_name = M.name ^ ".to_key" in
      fun str ->
        verify_length str key_size fn_name ;
        T.to_bytes str

    let of_auth auth = T.of_bytes auth

    let to_auth =
      let fn_name = M.name ^ ".to_auth" in
      fun str ->
        verify_length str auth_size fn_name ;
        T.to_bytes str

    let auth key message =
      let auth = Storage.Bytes.create auth_size in
      let ret =
        C.auth
          (Storage.Bytes.to_ptr auth)
          (T.to_ptr message) (T.len_ullong message) (Storage.Bytes.to_ptr key)
      in
      assert (ret = 0) ;
      (* always returns 0 *)
      auth

    let verify key auth message =
      let ret =
        C.auth_verify
          (Storage.Bytes.to_ptr auth)
          (T.to_ptr message) (T.len_ullong message) (Storage.Bytes.to_ptr key)
      in
      if ret <> 0 then raise Verification_failure
  end

  module Bytes = Make (Storage.Bytes)
  module Bigbytes = Make (Storage.Bigbytes)
end

module Auth = Gen_auth (struct
  let scope = "auth"

  let primitive = "hmacsha512256"

  let name = "Auth"
end)

module One_time_auth = Gen_auth (struct
  let scope = "onetimeauth"

  let primitive = "poly1305"

  let name = "One_time_auth"
end)

module Hash = struct
  module C = C.Hash

  let primitive = C.primitive

  let size = Size_t.to_int (C.hashbytes ())

  (* Invariant: a hash is size bytes long. *)
  type hash = Bytes.t

  let equal = Verify.equal_fn size

  module type S = sig
    type storage

    val of_hash : hash -> storage

    val to_hash : storage -> hash

    val digest : storage -> hash
  end

  module Make (T : Storage.S) = struct
    module C = C.Make (T)

    type storage = T.t

    let of_hash str = T.of_bytes str

    let to_hash str =
      if T.length str <> size then raise (Size_mismatch "Hash.to_hash") ;
      T.to_bytes str

    let digest str =
      let hash = Storage.Bytes.create size in
      let ret =
        C.hash (Storage.Bytes.to_ptr hash) (T.to_ptr str) (T.len_ullong str)
      in
      assert (ret = 0) ;
      (* always returns 0 *)
      hash
  end

  module Bytes = Make (Storage.Bytes)
  module Bigbytes = Make (Storage.Bigbytes)
end

module Generichash = struct
  module C = C.Generichash

  let primitive = C.primitive

  type 'a key = Bytes.t

  type secret_key = secret key

  let wipe_key = wipe

  let size_default = Size_t.to_int (C.hashbytes ())

  let size_min = Size_t.to_int (C.hashbytesmin ())

  let size_max = Size_t.to_int (C.hashbytesmax ())

  let size_of_hash h = Bytes.length h

  let compare = Bytes.compare

  let key_size_default = Size_t.to_int (C.keybytes ())

  let key_size_min = Size_t.to_int (C.keybytesmin ())

  let key_size_max = Size_t.to_int (C.keybytesmax ())

  let size_of_key k = Bytes.length k

  let random_key () = Random.Bytes.generate key_size_default

  let derive_key key_size =
    if key_size < key_size_min || key_size > key_size_max then
      raise (Size_mismatch "Generichash.derive_key") ;
    Password_hash.derive_key key_size

  type hash = Bytes.t

  type state =
    { ptr : Type.Generichash.state Static.structure ptr
    ; size : int
    ; mutable final : bool
    }

  let init ?(key = Bytes.of_string "") ?(size = size_default) () =
    if size < size_min || size > size_max then
      raise (Size_mismatch "Generichash.init") ;
    let ptr = allocate_n Type.Generichash.state ~count:1 in
    let ret =
      C.init ptr (Storage.Bytes.to_ptr key)
        (Size_t.of_int (size_of_key key))
        (Size_t.of_int size)
    in
    assert (ret = 0) ;
    (* always returns 0 *)
    { ptr; size; final = false }

  let copy state =
    let ptr = allocate_n Type.Generichash.state ~count:1 in
    memcpy ~src:state.ptr ~dest:ptr Type.Generichash.state ;
    { state with ptr }

  let final state =
    if state.final then raise (Already_finalized "Generichash.final")
    else
      let hash = Storage.Bytes.create state.size in
      let ret =
        C.final state.ptr (Storage.Bytes.to_ptr hash) (Size_t.of_int state.size)
      in
      assert (ret = 0) ;
      (* always returns 0 *)
      state.final <- true ;
      hash

  module type S = sig
    type storage

    val of_hash : hash -> storage

    val to_hash : storage -> hash

    val of_key : secret key -> storage

    val to_key : storage -> secret key

    val digest : ?size:int -> storage -> hash

    val digest_with_key : secret key -> ?size:int -> storage -> hash

    val update : state -> storage -> unit
  end

  module Make (T : Storage.S) = struct
    module C = C.Make (T)

    type storage = T.t

    let of_hash str = T.of_bytes str

    let to_hash str =
      let len = T.length str in
      if len < size_min || len > size_max then
        raise (Size_mismatch "Generichash.to_hash") ;
      T.to_bytes str

    let of_key str = T.of_bytes str

    let to_key str =
      let len = T.length str in
      if len < key_size_min || len > key_size_max then
        raise (Size_mismatch "Generichash.to_key") ;
      T.to_bytes str

    let digest_internal size key str =
      let hash = Storage.Bytes.create size in
      let ret =
        C.hash
          (Storage.Bytes.to_ptr hash)
          (Size_t.of_int size) (T.to_ptr str) (T.len_ullong str)
          (Storage.Bytes.to_ptr key)
          (Size_t.of_int (size_of_key key))
      in
      assert (ret = 0) ;
      (* always returns 0 *)
      hash

    let digest_with_key key ?(size = size_default) str =
      if size < size_min || size > size_max then
        raise (Size_mismatch "Generichash.digest_with_key") ;
      digest_internal size key str

    let digest ?(size = size_default) str =
      if size < size_min || size > size_max then
        raise (Size_mismatch "Generichash.digest") ;
      (* TODO: The key should be NULL here but we can't represent that
         with ctypes yet without giving up zero-copy passing.
         See <https://github.com/ocamllabs/ocaml-ctypes/issues/316>.
      *)
      digest_internal size (Bytes.create 0) str

    let update state str =
      if state.final then raise (Already_finalized "Generichash.update")
      else
        let ret = C.update state.ptr (T.to_ptr str) (T.len_ullong str) in
        assert (ret = 0) ;
        (* always returns 0 *)
        ()
  end

  module Bytes = Make (Storage.Bytes)
  module Bigbytes = Make (Storage.Bigbytes)
end

let initialized =
  match C.init () with
  | 0 | 1 ->
      true
  | -1 ->
      false
  | _ ->
      failwith "libsodium initialization failed unexpectedly"
