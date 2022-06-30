[%%import "/src/config.mlh"]

open Core_kernel

[%%ifdef consensus_mechanism]

open Snark_params.Tick

[%%endif]

module type S = sig
  exception Too_long_user_memo_input

  exception Too_long_digestible_string

  type t [@@deriving sexp, equal, compare, hash, yojson]

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving bin_io, sexp, equal, compare, hash, yojson, version]
    end

    module Latest = V1
  end

  [%%ifdef consensus_mechanism]

  module Checked : sig
    type unchecked = t

    type t = private Boolean.var array

    val constant : unchecked -> t
  end

  (** typ representation *)
  val typ : (Checked.t, t) Typ.t

  [%%endif]

  val dummy : t

  val empty : t

  val to_base58_check : t -> string

  val of_base58_check_exn : string -> t

  (** for a memo of bytes, return a plaintext string
      for a memo of a digest, return a hex-encoded string, prefixed by '0x'
  *)
  val to_string_hum : t -> string

  (** is the memo a digest *)
  val is_digest : t -> bool

  (** is the memo well-formed *)
  val is_valid : t -> bool

  (** bound on length of strings to digest *)
  val max_digestible_string_length : int

  (** bound on length of strings or bytes in memo *)
  val max_input_length : int

  (** create a memo by digesting a string; raises [Too_long_digestible_string] if
      length exceeds [max_digestible_string_length]
  *)
  val create_by_digesting_string_exn : string -> t

  (** create a memo by digesting a string; returns error if
      length exceeds [max_digestible_string_length]
  *)
  val create_by_digesting_string : string -> t Or_error.t

  (** create a memo from bytes of length up to max_input_length;
      raise [Too_long_user_memo_input] if length is greater
  *)
  val create_from_bytes_exn : bytes -> t

  (** create a memo from bytes of length up to max_input_length; returns
      error is length is greater
  *)
  val create_from_bytes : bytes -> t Or_error.t

  (** create a memo from a string of length up to max_input_length;
      raise [Too_long_user_memo_input] if length is greater
  *)
  val create_from_string_exn : string -> t

  (** create a memo from a string of length up to max_input_length;
      returns error if length is greater
  *)
  val create_from_string : string -> t Or_error.t

  (** convert a memo to a list of bools
  *)
  val to_bits : t -> bool list

  type raw =
    | Digest of string  (** The digest of the string, encoded by base58-check *)
    | Bytes of string  (** A string containing the raw bytes in the memo. *)

  (** Convert into a raw representation.

      Raises if the tag or length are invalid.
  *)
  val to_raw_exn : t -> raw

  (** Convert back into the raw input bytes.

      Raises if the tag or length are invalid, or if the memo was a digest.
      Equivalent to [to_raw_exn] and then a match on [Bytes].
  *)
  val to_raw_bytes_exn : t -> string

  (** Convert from a raw representation.

      Raises if the digest is not a valid base58-check string, or if the bytes
      string is too long.
  *)
  val of_raw_exn : raw -> t
end
