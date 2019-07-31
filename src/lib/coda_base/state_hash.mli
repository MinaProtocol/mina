include Data_hash.Full_size

include Codable.Base58_check_intf with type t := t

val zero : Crypto_params.Tick0.field

val raw_hash_bytes : t -> string

val to_bytes : [`Use_to_base58_check_or_raw_hash_bytes]
