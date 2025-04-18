open Core_kernel

(* bin_io required by rpc_parallel *)
type t = Testnet | Mainnet | Other_network of string
[@@deriving bin_io_unversioned]
