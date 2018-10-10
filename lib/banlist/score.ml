open Unsigned
open Core_kernel
include UInt32
include Binable.Of_stringable (UInt32)

let serialize = Fn.compose Bigstring.of_string to_string

let deserialize = Fn.compose of_string Bigstring.to_string
