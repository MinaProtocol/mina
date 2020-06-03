open Core_kernel

include Blake2.Make ()

module Base58_check = Codable.Make_base58_check (struct
  type t = Stable.Latest.t [@@deriving bin_io_unversioned, compare]

  let version_byte = Base58_check.Version_bytes.transaction_hash

  let description = "Transaction Hash"
end)

[%%define_locally
Base58_check.(of_base58_check, of_base58_check_exn, to_base58_check)]

let hash_user_command = Fn.compose digest_string User_command.to_base58_check

let hash_fee_transfer =
  Fn.compose digest_string Fee_transfer.Single.to_base58_check

let hash_coinbase = Fn.compose digest_string Coinbase.to_base58_check
