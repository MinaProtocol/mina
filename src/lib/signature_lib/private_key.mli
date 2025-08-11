(** Private keys for cryptographic signatures.

    This module provides private keys based on the inner curve scalar field,
    used for generating cryptographic signatures in the Mina protocol. *)

open Core_kernel
open Snark_params.Tick

[%%versioned:
module Stable : sig
  module V1 : sig
    [@@@with_all_version_tags]

    (** A private key is represented as a scalar value on the inner curve *)
    type t = Inner_curve.Scalar.t [@@deriving compare, sexp]

    (** Convert to the latest version (identity function for latest version) *)
    val to_latest : t -> t

    (** Generator for creating random private keys for testing *)
    val gen : t Quickcheck.Generator.t
  end
end]

(** Generator for creating random private keys for testing *)
val gen : t Quickcheck.Generator.t

(** Generate a new private key using cryptographically secure randomness *)
val create : unit -> t

(** Comparable and binable interface for private keys *)
include Comparable.S_binable with type t := t

(** Deserialize a private key from a bigstring.
    @raise Failure if the bigstring cannot be parsed as a valid private key *)
val of_bigstring_exn : Bigstring.t -> t

(** Serialize a private key to a bigstring *)
val to_bigstring : t -> Bigstring.t

(** Base58Check encoding utilities for private keys *)
module Base58_check : sig
  (** Encode a string using Base58Check encoding *)
  val encode : string -> string

  (** Decode a Base58Check encoded string.
      @raise Failure if the string is not valid Base58Check *)
  val decode_exn : string -> string
end

(** Encode a private key as a Base58Check string for safe display/storage *)
val to_base58_check : t -> string

(** Parse a private key from a Base58Check encoded string.
    @raise Failure if the string is not a valid Base58Check encoded private
    key *)
val of_base58_check_exn : string -> t

(** Convert a private key to an S-expression using Base58Check encoding *)
val sexp_of_t : t -> Sexp.t

(** Parse a private key from an S-expression containing a Base58Check string.
    @raise Failure if the S-expression cannot be parsed *)
val t_of_sexp : Sexp.t -> t

(** Convert a private key to JSON using Base58Check encoding
    @return a JSON string containing the Base58Check encoded private key
*)
val to_yojson : t -> [> `String of string ]

(** Parse a private key from JSON.
    Only accepts a JSON string containing a Base58Check encoded private key.
    Returns [Ok private_key] on success or [Error message] on failure. *)
val of_yojson : [> `String of string ] -> (t, string) result
