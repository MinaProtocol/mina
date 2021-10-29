type t = Testnet | Mainnet
[@@deriving sexp, ord, equal, bin_io_unversioned, dhall_type]

let to_yojson = function
  | Testnet ->
      `String "testnet"
  | Mainnet ->
      `String "mainnet"

let of_yojson = function
  | `String s -> (
      match Core_kernel.String.lowercase s with
      | "testnet" ->
          Ok Testnet
      | "mainnet" ->
          Ok Mainnet
      | _ ->
          Error "Signature_kind.of_yojson: Expected 'testnet' or 'mainnet'" )
  | _ ->
      Error "Signature_kind.of_yojson: Expected a string"
