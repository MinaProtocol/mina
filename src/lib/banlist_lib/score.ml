open Unsigned
open Core_kernel

(* Added binable to Score and serialization methods to make it easy for Score to be serialized into Rocksdb *)
include UInt32
include Binable.Of_stringable (UInt32)

let serialize = Fn.compose Bigstring.of_string to_string

let deserialize = Fn.compose of_string Bigstring.to_string
