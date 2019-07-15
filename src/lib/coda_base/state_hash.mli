include Data_hash.Full_size

(** string encoding (Base58Check) *)
val to_string : t -> string

(** string (Base58Check) decoding *)
val of_string : string -> t

(** explicit Base58Check encoding *)
val to_base58_check : t -> string

(** Base58Check decoding *)
val of_base58_check : string -> t Base.Or_error.t

(** Base58Check decoding *)
val of_base58_check_exn : string -> t

val zero : Crypto_params.Tick0.field
