open Core_kernel

include Data_hash.Full_size

include Comparable.S with type t := t

val zero : Crypto_params.Tick0.field
