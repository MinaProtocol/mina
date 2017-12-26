open Core_kernel

(* TODO: Use Int64.t *)
type t = Bigstring.t
[@@deriving bin_io]

module Snarkable (Impl : Camlsnark.Snark_intf.S) =
  Bits.Make_bigstring(Impl)(struct let byte_length = 8 end)
