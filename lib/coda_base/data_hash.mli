open Core_kernel
open Coda_spec

module Make_full_size () : Hash_intf.Full_size.S

module Make_small (M : sig val length_in_bits : int end) : Hash_intf.Small.S
