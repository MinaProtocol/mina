open Core_kernel

type t = Testnet | Mainnet | Other_network of string
[@@deriving bin_io_unversioned]
