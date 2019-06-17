(* base58_check.mli -- implementation of Base58Check algorithm *)

exception Invalid_base58_checksum

exception Invalid_base58_check_length

(** apply Base58Check algorithm to version byte and payload *)
val base58_check : version_byte:char -> payload:string -> string

(** decode Base58Check result into version byte and payload; can raise the above exceptions *)
val base58_check_decode_exn : string -> char * string
