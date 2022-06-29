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

(** A binding to {{: https://github.com/jedisct1/libsodium } libsodium}
    which wraps {{: http://nacl.cr.yp.to/ } NaCl} *)

(** Raised when message authentication fails. *)
exception Verification_failure

(** Raised when attempting to deserialize a malformed key, nonce, or
    attempting to use a bad hash length. *)
exception Size_mismatch of string

(** Raised when attempting to finalize an already finalized stream state. *)
exception Already_finalized of string

(** Phantom type indicating that the key is public. *)
type public

(** Phantom type indicating that the key is secret. *)
type secret

(** Phantom type indicating that the key is composed of a secret key and
    a public key. Such a key must be treated as a secret key. *)
type channel

type bigbytes =
  (char, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t

module Random : sig
  val stir : unit -> unit

  module type S = sig
    type storage

    val generate_into : storage -> unit

    val generate : int -> storage
  end

  module Bytes : S with type storage = Bytes.t

  module Bigbytes : S with type storage = bigbytes
end

module Box : sig
  type 'a key

  type secret_key = secret key

  type public_key = public key

  type channel_key = channel key

  type keypair = secret key * public key

  type nonce

  (** Primitive used by this implementation.
      Currently ["curve25519xsalsa20poly1305"]. *)
  val primitive : string

  (** Size of public keys, in bytes. *)
  val public_key_size : int

  (** Size of secret keys, in bytes. *)
  val secret_key_size : int

  (** Size of channel keys, in bytes. *)
  val channel_key_size : int

  (** Size of nonces, in bytes. *)
  val nonce_size : int

  (** [random_keypair ()] generates a random key pair. *)
  val random_keypair : unit -> keypair

  (** [random_nonce ()] generates a random nonce. *)
  val random_nonce : unit -> nonce

  (** [nonce_of_bytes b] creates a nonce out of bytes [b].

      @raise Size_mismatch if [b] is not {!nonce_size} bytes long *)
  val nonce_of_bytes : Bytes.t -> nonce

  (** [increment_nonce ?step n] interprets nonce [n] as a big-endian
      number and returns the sum of [n] and [step] with wrap-around.
      The default [step] is 1. *)
  val increment_nonce : ?step:int -> nonce -> nonce

  (** [wipe_key k] overwrites [k] with zeroes. *)
  val wipe_key : 'a key -> unit

  (** [precompute sk pk] precomputes the channel key for the secret key [sk]
      and the public key [pk], which can be used to speed up processing
      of any number of messages. *)
  val precompute : secret key -> public key -> channel key

  (** [equal_public_keys a b] checks [a] and [b] for equality in constant
      time. *)
  val equal_public_keys : public key -> public key -> bool

  (** [equal_secret_keys a b] checks [a] and [b] for equality in constant
      time. *)
  val equal_secret_keys : secret key -> secret key -> bool

  (** [equal_channel_keys a b] checks [a] and [b] for equality in constant
      time. *)
  val equal_channel_keys : channel key -> channel key -> bool

  (** [compare_public_keys a b] compares [a] and [b]. *)
  val compare_public_keys : public key -> public key -> int

  module type S = sig
    type storage

    (** [of_public_key k] converts [k] to type [storage]. The result
        is {!public_key_size} bytes long. *)
    val of_public_key : public key -> storage

    (** [to_public_key s] converts [s] to a public key.

        @raise Size_mismatch if [s] is not {!public_key_size} bytes long *)
    val to_public_key : storage -> public key

    (** [of_secret_key k] converts [k] to {!storage}. The result is
        {!secret_key_size} bytes long. *)
    val of_secret_key : secret key -> storage

    (** [to_secret_key s] converts [s] to a secret key.

        @raise Size_mismatch if [s] is not {!secret_key_size} bytes long *)
    val to_secret_key : storage -> secret key

    (** [of_channel_key k] converts [k] to {!storage}. The result is
        {!channel_key_size} bytes long. *)
    val of_channel_key : channel key -> storage

    (** [to_channel_key s] converts [s] to a channel key.

        @raise Size_mismatch if [s] is not {!channel_key_size} bytes long *)
    val to_channel_key : storage -> channel key

    (** [of_nonce n] converts [n] to {!storage}. The result is
        {!nonce_size} bytes long. *)
    val of_nonce : nonce -> storage

    (** [to_nonce s] converts [s] to a nonce.

        @raise Size_mismatch if [s] is not {!nonce_size} bytes long *)
    val to_nonce : storage -> nonce

    (** [box sk pk m n] encrypts and authenticates a message [m] using
        the sender's secret key [sk], the receiver's public key [pk], and
        a nonce [n]. *)
    val box : secret key -> public key -> storage -> nonce -> storage

    (** [box_open sk pk c n] verifies and decrypts a ciphertext [c] using
        the receiver's secret key [sk], the sender's public key [pk], and
        a nonce [n].

        @raise Verification_failure if authenticity of message cannot
        be verified *)
    val box_open : secret key -> public key -> storage -> nonce -> storage

    (** [fast_box ck m n] encrypts and authenticates a message [m] using
        the channel key [ck] precomputed from sender's secret key
        and the receiver's public key, and a nonce [n]. *)
    val fast_box : channel key -> storage -> nonce -> storage

    (** [fast_box_open ck c n] verifies and decrypts a ciphertext [c] using
        the channel key [ck] precomputed from receiver's secret key
        and the sender's public key, and a nonce [n].

        @raise Verification_failure if authenticity of message cannot
        be verified *)
    val fast_box_open : channel key -> storage -> nonce -> storage
  end

  module Bytes : S with type storage = Bytes.t

  module Bigbytes : S with type storage = bigbytes
end

module Scalar_mult : sig
  type group_elt

  type integer

  (** Primitive used by this implementation. Currently ["curve25519"]. *)
  val primitive : string

  (** Size of group elements, in bytes. *)
  val group_elt_size : int

  (** Size of integers, in bytes. *)
  val integer_size : int

  (** [equal_group_elt a b] checks [a] and [b] for equality in constant time. *)
  val equal_group_elt : group_elt -> group_elt -> bool

  (** [equal_integer a b] checks [a] and [b] for equality in constant time. *)
  val equal_integer : integer -> integer -> bool

  (** [mult n p] multiplies a group element [p] by an integer [n]. *)
  val mult : integer -> group_elt -> group_elt

  (** [base n] computes the scalar product of a standard group
      element and an integer [n]. *)
  val base : integer -> group_elt

  module type S = sig
    type storage

    (** [of_group_elt ge] converts [ge] to {!storage}. The result
        is {!group_elt_size} bytes long. *)
    val of_group_elt : group_elt -> storage

    (** [to_group_elt s] converts [s] to a group_elt.

        @raise Size_mismatch if [s] is not {!group_elt_size} bytes long *)
    val to_group_elt : storage -> group_elt

    (** [of_integer i] converts [i] to {!storage}. The result
        is {!integer_size} bytes long. *)
    val of_integer : integer -> storage

    (** [to_integer s] converts [s] to a integer.

        @raise Size_mismatch if [s] is not {!integer_size} bytes long *)
    val to_integer : storage -> integer
  end

  module Bytes : S with type storage = Bytes.t

  module Bigbytes : S with type storage = bigbytes
end

module Sign : sig
  type 'a key

  type secret_key = secret key

  type public_key = public key

  type keypair = secret key * public key

  type signature

  type seed

  (** Primitive used by this implementation. Currently ["ed25519"]. *)
  val primitive : string

  (** Size of public keys, in bytes. *)
  val public_key_size : int

  (** Size of secret keys, in bytes. *)
  val secret_key_size : int

  (** Size of signatures, in bytes. *)
  val signature_size : int

  (** Size of signing key seeds, in bytes. *)
  val seed_size : int

  (** [random_keypair ()] generates a random key pair. *)
  val random_keypair : unit -> keypair

  (** [seed_keypair seed] generates a key pair from secret [seed]. *)
  val seed_keypair : seed -> keypair

  (** [secret_key_to_seed sk] extracts the secret key [sk]'s {!seed}. *)
  val secret_key_to_seed : secret key -> seed

  (** [secret_key_to_public_key sk] extract the secret key [sk]'s
      {!public_key}. *)
  val secret_key_to_public_key : secret key -> public key

  (** [wipe_key k] overwrites [k] with zeroes. *)
  val wipe_key : 'a key -> unit

  (** [equal_public_keys a b] checks [a] and [b] for equality in constant
      time. *)
  val equal_public_keys : public key -> public key -> bool

  (** [equal_secret_keys a b] checks [a] and [b] for equality in constant
      time. *)
  val equal_secret_keys : secret key -> secret key -> bool

  (** [compare_public_keys a b] compares [a] and [b]. *)
  val compare_public_keys : public key -> public key -> int

  (** [box_keypair kp] is the {!Box.keypair} extracted from [kp]. *)
  val box_keypair : keypair -> Box.keypair

  (** [box_public_key k] is the {!Box.public_key} extracted from [k]. *)
  val box_public_key : public key -> Box.public_key

  (** [box_secret_key k] is the {!Box.secret_key} extracted from [k]. *)
  val box_secret_key : secret key -> Box.secret_key

  module type S = sig
    type storage

    (** [of_public_key k] converts [k] to {!storage}. The result is
        {!public_key_size} bytes long. *)
    val of_public_key : public key -> storage

    (** [to_public_key s] converts [s] to a public key.

        @raise Size_mismatch if [s] is not {!public_key_size} bytes
        long *)
    val to_public_key : storage -> public key

    (** [of_secret_key k] converts [k] to {!storage}. The result is
        {!secret_key_size} bytes long. *)
    val of_secret_key : secret key -> storage

    (** [to_secret_key s] converts [s] to a secret key.

        @raise Size_mismatch if [s] is not {!secret_key_size} bytes
        long *)
    val to_secret_key : storage -> secret key

    (** [of_signature a] converts [a] to {!storage}. The result is
        {!signature_size} bytes long. *)
    val of_signature : signature -> storage

    (** [to_signature s] converts [s] to a signature.

        @raise Size_mismatch if [s] is not {!signature_size} bytes long *)
    val to_signature : storage -> signature

    (** [of_seed s] converts [s] to type {!storage}. The result is
        {!seed_size} bytes long. *)
    val of_seed : seed -> storage

    (** [to_seed s] converts [s] to a seed.

        @raise Size_mismatch if [s] is not {!seed_size} bytes long *)
    val to_seed : storage -> seed

    (** [sign sk m] signs a message [m] using the signer's secret key [sk],
        and returns the resulting signed message. *)
    val sign : secret key -> storage -> storage

    (** [sign_open pk sm] verifies the signature in [sm] using the signer's
        public key [pk], and returns the message.

        @raise Verification_failure if authenticity of message cannot
        be verified *)
    val sign_open : public key -> storage -> storage

    (** [sign_detached sk m] signs a message [m] using the signer's secret
        key [sk], and returns the signature. *)
    val sign_detached : secret key -> storage -> signature

    (** [verify pk s m] checks that [s] is a correct signature of a message
        [m] under the public key [pk].

        @raise Verification_failure if [s] is not a correct signature
        of [m] under [pk] *)
    val verify : public key -> signature -> storage -> unit
  end

  module Bytes : S with type storage = Bytes.t

  module Bigbytes : S with type storage = bigbytes
end

module Password_hash : sig
  type salt

  type password

  (** Primitive used by this implementation. Currently ["argon2i"]. *)
  val primitive : string

  (** Size of password hashes, in bytes. *)
  val password_hash_size : int

  (** Size of salts, in bytes. *)
  val salt_size : int

  (** Parameters of the {!primitive} algorithm used to derive secret
      keys and hash passwords. This algorithm generates data (the
      secret key or the hash) from a human chosen password and a salt
      using a time and memory consuming algorithm to prevent
      bruteforce attacks. *)
  type difficulty =
    { mem_limit : int64
          (** The amount of memory used by the algorithm.
                           The more memory the better. *)
    ; ops_limit : int
          (** The number of passes of the algorithm over
                         the memory.  The more passes the better, to
                         be adjusted to the type of application. *)
    }

  (** The base line of difficulty, for online, interactive
      applications. Currently 3 passes over 32MiB. *)
  val interactive : difficulty

  (** Currently 6 passes and 128MiB. *)
  val moderate : difficulty

  (** For highly sensitive data and non-interactive operations.
      Currently 8 passes over 512MiB. Takes about 3.5 seconds on a 2.8
      Ghz Core i7 CPU. *)
  val sensitive : difficulty

  (** [wipe_password pw] overwrites [pw] with zeroes. *)
  val wipe_password : password -> unit

  (** [random_salt ()] generates a random salt. *)
  val random_salt : unit -> salt

  (** [salt_of_bytes b] creates a salt out of bytes [b].

      @raise Size_mismatch if [b] is not {!salt_size} bytes long *)
  val salt_of_bytes : Bytes.t -> salt

  module type S = sig
    type storage

    (** [of_salt s] converts [s] to {!storage}. The result is
        {!salt_size} bytes long. *)
    val of_salt : salt -> storage

    (** [to_salt s] converts [s] to a salt.

        @raise Size_mismatch if [s] is not {!salt_size} bytes long *)
    val to_salt : storage -> salt

    (** [wipe_to_password s] copies a password [s] from {!storage} and
        wipes [s]. *)
    val wipe_to_password : storage -> password

    (** [hash_password d pw] uses the key derivation algorithm to
        create a safely storable hash of the password of size
        {!password_hash_size}. It randomly generates a salt, and
        stores the result of the derivation, along with the salt and
        parameters [d], so that {!verify_password} can later verify
        the hash. *)
    val hash_password : difficulty -> password -> storage

    (** [verify_password_hash h p] uses the key derivation algorithm to
        check that a safely storable password hash [h] actually matches
        the password [p].

        @raise Size_mismatch if [h] is not {!password_hash_size} bytes long *)
    val verify_password_hash : storage -> password -> bool
  end

  module Bytes : S with type storage = Bytes.t

  module Bigbytes : S with type storage = bigbytes
end

module Secret_box : sig
  type 'a key

  type secret_key = secret key

  type nonce

  (** Primitive used by this implementation. Currently ["xsalsa20poly1305"]. *)
  val primitive : string

  (** Size of keys, in bytes. *)
  val key_size : int

  (** Size of nonces, in bytes. *)
  val nonce_size : int

  (** [random_key ()] generates a random secret key . *)
  val random_key : unit -> secret key

  (** [derive_key difficulty pw salt] derives a key from a human
      generated password. Since the derivation depends on both
      [difficulty] and [salt], it is necessary to store them alongside
      the ciphertext. Using a constant salt is insecure because it
      increases the effectiveness of rainbow tables. Generate the salt
      with a function like {!Password_hash.random_salt} instead. *)
  val derive_key :
       Password_hash.difficulty
    -> Password_hash.password
    -> Password_hash.salt
    -> secret_key

  (** [random_nonce ()] generates a random nonce. *)
  val random_nonce : unit -> nonce

  (** [nonce_of_bytes b] creates a nonce out of bytes [b].

      @raise Size_mismatch if [b] is not {!nonce_size} bytes long *)
  val nonce_of_bytes : Bytes.t -> nonce

  (** [increment_nonce ?step n] interprets nonce [n] as a big-endian
      number and returns the sum of [n] and [step] with wrap-around.
      The default [step] is 1. *)
  val increment_nonce : ?step:int -> nonce -> nonce

  (** [wipe_key k] overwrites [k] with zeroes. *)
  val wipe_key : secret key -> unit

  (** [equal_keys a b] checks [a] and [b] for equality in constant time. *)
  val equal_keys : secret key -> secret key -> bool

  module type S = sig
    type storage

    (** [of_key k] converts [k] to {!storage}. The result is
        {!key_size} bytes long. *)
    val of_key : secret key -> storage

    (** [to_key s] converts [s] to a secret key.

        @raise Size_mismatch if [s] is not {!key_size} bytes long *)
    val to_key : storage -> secret key

    (** [of_nonce n] converts [n] to {!storage}. The result is
        {!nonce_size} bytes long. *)
    val of_nonce : nonce -> storage

    (** [to_nonce s] converts [s] to a nonce.

        @raise Size_mismatch if [s] is not {!nonce_size} bytes long *)
    val to_nonce : storage -> nonce

    (** [secret_box k m n] encrypts and authenticates a message [m] using
        a secret key [k] and a nonce [n], and returns the resulting
        ciphertext. *)
    val secret_box : secret key -> storage -> nonce -> storage

    (** [secret_box_open k c n] verifies and decrypts a ciphertext [c] using
        a secret key [k] and a nonce [n], and returns the resulting plaintext
        [m].

        @raise Verification_failure if authenticity of message cannot
        be verified *)
    val secret_box_open : secret key -> storage -> nonce -> storage
  end

  module Bytes : S with type storage = Bytes.t

  module Bigbytes : S with type storage = bigbytes
end

module Stream : sig
  type 'a key

  type secret_key = secret key

  type nonce

  (** Primitive used by this implementation. Currently ["xsalsa20"]. *)
  val primitive : string

  (** Size of keys, in bytes. *)
  val key_size : int

  (** Size of nonces, in bytes. *)
  val nonce_size : int

  (** [random_key ()] generates a random secret key. *)
  val random_key : unit -> secret key

  (** [derive_key difficulty pw salt] derives a key from a human
      generated password. Since the derivation depends on both
      [difficulty] and [salt], it is necessary to store them alongside
      the ciphertext. Using a constant salt is insecure because it
      increases the effectiveness of rainbow tables. Generate the salt
      with a function like {!Password_hash.random_salt} instead. *)
  val derive_key :
       Password_hash.difficulty
    -> Password_hash.password
    -> Password_hash.salt
    -> secret_key

  (** [random_nonce ()] generates a random nonce. *)
  val random_nonce : unit -> nonce

  (** [nonce_of_bytes b] creates a nonce out of bytes [b].

      @raise Size_mismatch if [b] is not {!nonce_size} bytes long *)
  val nonce_of_bytes : Bytes.t -> nonce

  (** [increment_nonce ?step n] interprets nonce [n] as a big-endian
      number and returns the sum of [n] and [step] with wrap-around.
      The default [step] is 1. *)
  val increment_nonce : ?step:int -> nonce -> nonce

  (** [wipe_key k] overwrites [k] with zeroes. *)
  val wipe_key : secret key -> unit

  (** [equal_keys a b] checks [a] and [b] for equality in constant time. *)
  val equal_keys : secret key -> secret key -> bool

  module type S = sig
    type storage

    (** [of_key k] converts [k] to {!storage}. The result is
        {!key_size} bytes long. *)
    val of_key : secret key -> storage

    (** [to_key s] converts [s] to a secret key.

        @raise Size_mismatch if [s] is not {!key_size} bytes long *)
    val to_key : storage -> secret key

    (** [of_nonce n] converts [n] to {!storage}. The result is
        {!nonce_size} bytes long. *)
    val of_nonce : nonce -> storage

    (** [to_nonce s] converts [s] to a nonce.

        @raise Size_mismatch if [s] is not {!nonce_size} bytes long *)
    val to_nonce : storage -> nonce

    (** [stream k len n] produces a [len]-byte stream [c] as a function of
        a secret key [k] and a nonce [n]. *)
    val stream : secret key -> int -> nonce -> storage

    (** [stream_xor k m n] encrypts or decrypts a message [m] using
        a secret key [k] and a nonce [n]. *)
    val stream_xor : secret key -> storage -> nonce -> storage
  end

  module Bytes : S with type storage = Bytes.t

  module Bigbytes : S with type storage = bigbytes
end

module Auth : sig
  type 'a key

  type secret_key = secret key

  type auth

  (** Primitive used by this implementation. Currently ["hmacsha512256"]. *)
  val primitive : string

  (** Size of keys, in bytes. *)
  val key_size : int

  (** Size of authenticators, in bytes. *)
  val auth_size : int

  (** [random_key ()] generates a random secret key . *)
  val random_key : unit -> secret key

  (** [derive_key difficulty pw salt] derives a key from a human
      generated password. Since the derivation depends on both
      [difficulty] and [salt], it is necessary to store them alongside
      the authenticator. Using a constant salt is insecure because it
      increases the effectiveness of rainbow tables. Generate the salt
      with a function like {!Password_hash.random_salt} instead. *)
  val derive_key :
       Password_hash.difficulty
    -> Password_hash.password
    -> Password_hash.salt
    -> secret_key

  (** [wipe_key k] overwrites [k] with zeroes. *)
  val wipe_key : secret key -> unit

  (** [equal_keys a b] checks [a] and [b] for equality in constant time. *)
  val equal_keys : secret key -> secret key -> bool

  module type S = sig
    type storage

    (** [of_key k] converts [k] to {!storage}. The result is
        {!key_size} bytes long. *)
    val of_key : secret key -> storage

    (** [to_key s] converts [s] to a secret key.

        @raise Size_mismatch if [s] is not {!key_size} bytes long *)
    val to_key : storage -> secret key

    (** [of_auth a] converts [a] to {!storage}. The result is
        {!auth_size} bytes long. *)
    val of_auth : auth -> storage

    (** [to_auth s] converts [s] to an authenticator.

        @raise Size_mismatch if [s] is not {!auth_size} bytes long *)
    val to_auth : storage -> auth

    (** [auth k m] authenticates a message [m] using a secret key [k],
        and returns an authenticator [a].  *)
    val auth : secret key -> storage -> auth

    (** [verify k a m] checks that [a] is a correct authenticator
        of a message [m] under the secret key [k].

        @raise Verification_failure if [a] is not a correct authenticator
        of [m] under [k] *)
    val verify : secret key -> auth -> storage -> unit
  end

  module Bytes : S with type storage = Bytes.t

  module Bigbytes : S with type storage = bigbytes
end

module One_time_auth : sig
  include module type of Auth

  (** Primitive used by this implementation. Currently ["poly1305"]. *)
  val primitive : string
end

module Hash : sig
  type hash

  (** Primitive used by this implementation. Currently ["sha512"]. *)
  val primitive : string

  (** Size of hashes, in bytes. *)
  val size : int

  (** [equal a b] checks [a] and [b] for equality in constant time. *)
  val equal : hash -> hash -> bool

  module type S = sig
    type storage

    (** [of_hash h] converts [h] to {!storage}. The result is {!size}
        bytes long. *)
    val of_hash : hash -> storage

    (** [to_hash s] converts [s] to a hash.

        @raise Size_mismatch if [s] is not {!size} bytes long *)
    val to_hash : storage -> hash

    (** [digest m] computes a hash for message [m]. *)
    val digest : storage -> hash
  end

  module Bytes : S with type storage = Bytes.t

  module Bigbytes : S with type storage = bigbytes
end

module Generichash : sig
  type hash

  type state

  type 'a key

  type secret_key = secret key

  (** Primitive used by this implementation. Currently ["blake2b"]. *)
  val primitive : string

  (** [wipe_key k] overwrites [k] with zeroes. *)
  val wipe_key : secret key -> unit

  (** Default recommended output size, in bytes. *)
  val size_default : int

  (** Minimum supported output size, in bytes. *)
  val size_min : int

  (** Maximum supported output size, in bytes. *)
  val size_max : int

  (** [size_of_hash hash] is the size, in bytes, of the {!hash} [hash]. *)
  val size_of_hash : hash -> int

  (** [compare h h'] is 0 if [h] and [h'] are equal, a negative
      integer if [h] is less than [h'], and a positive integer if [h]
      is greater than [h']. [compare] {i {b is not constant time}}. *)
  val compare : hash -> hash -> int

  (** Default recommended key size, in bytes. *)
  val key_size_default : int

  (** Minimum supported key size, in bytes. *)
  val key_size_min : int

  (** Maximum supported key size, in bytes. *)
  val key_size_max : int

  (** [size_of_key key] is the size, in bytes, of the {!key} [key]. *)
  val size_of_key : secret key -> int

  (** [random_key ()] generates a random secret key of
      {!key_size_default} bytes. *)
  val random_key : unit -> secret key

  (** [derive_key key_size difficulty pw salt] derives a key of length
      [key_size] from a human generated password. Since the derivation
      depends on both [difficulty] and [salt], it is necessary to
      store them alongside the hash. Using a constant salt is insecure
      because it increases the effectiveness of rainbow
      tables. Generate the salt with a function like
      {!Password_hash.random_salt} instead.

      @raise Size_mismatch if [key_size] is greater than {!key_size_max} or
      less than {!key_size_min} *)
  val derive_key :
       int
    -> Password_hash.difficulty
    -> Password_hash.password
    -> Password_hash.salt
    -> secret_key

  (** [init ?key ?size ()] is a streaming hash state keyed with [key]
      if supplied and computing a hash of size [size] (default
      {!size_default}).

      @raise Size_mismatch if [size] is greater than {!size_max} or
      less than {!size_min} *)
  val init : ?key:secret key -> ?size:int -> unit -> state

  (** [copy state] is a copy of the {!state} [state] which can diverge
      from the original (including finalization). *)
  val copy : state -> state

  (** [final state] is the final hash of the inputs collected in
      [state].

      @raise Already_finalized if [state] has already had [final]
      applied to it *)
  val final : state -> hash

  module type S = sig
    type storage

    (** [of_hash h] converts [h] to {!storage}. The result
        is [size_of_hash h] bytes long. *)
    val of_hash : hash -> storage

    (** [to_hash s] converts [s] to a hash.

        @raise Size_mismatch if [s] is greater than {!size_max} or
        less than {!size_min} bytes long *)
    val to_hash : storage -> hash

    (** [of_key k] converts key [k] to {!storage}. The result is
        [size_of_key k] bytes long. *)
    val of_key : secret key -> storage

    (** [to_key s] converts [s] to a {!secret} {!key}.

        @raise Size_mismatch if [s] is greater than {!key_size_max} or
        less than {!key_size_min} bytes long *)
    val to_key : storage -> secret key

    (** [digest ?size m] computes a hash of size [size] (default
        {!size_default}) for message [m]. *)
    val digest : ?size:int -> storage -> hash

    (** [digest_with_key key m] computes a hash of size [size]
        (default {!size_default} keyed by [key] for message [m]. *)
    val digest_with_key : secret key -> ?size:int -> storage -> hash

    (** [update state m] updates the {!state} [state] with input [m].

        @raise Already_finalized if [state] has already had {!final}
        applied to it *)
    val update : state -> storage -> unit
  end

  module Bytes : S with type storage = Bytes.t

  module Bigbytes : S with type storage = bigbytes
end

val initialized : bool
