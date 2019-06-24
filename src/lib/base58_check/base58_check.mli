open Core_kernel

(* base58_check.mli -- implementation of Base58Check algorithm *)

exception Invalid_base58_checksum

exception Invalid_base58_version_byte

exception Invalid_base58_check_length

(** apply Base58Check algorithm to version byte and payload *)
val encode : version_byte:char -> payload:string -> string

(** decode Base58Check result into payload; can raise the above
 * exceptions and a B58.Invalid_base58_character *)
val decode_exn : version_byte:char -> string -> string

(** decode Base58Check result into payload *)
val decode : version_byte:char -> string -> string Or_error.t

module Version_bytes : module type of Version_bytes
