(* state_hash.mli *)

[%%import "/src/config.mlh"]

[%%ifdef consensus_mechanism]

open Snark_params.Tick

[%%else]

open Snark_params_nonconsensus

[%%endif]

include Data_hash.Full_size

include Codable.Base58_check_intf with type t := t

val zero : Field.t

val raw_hash_bytes : t -> string

val to_bytes : [`Use_to_base58_check_or_raw_hash_bytes]

(* value of type t, not a valid hash *)
val dummy : t

val to_decimal_string : t -> string
