type t = Testnet | Mainnet | Other_network of string

let t =
  match Node_config.network with
  | "testnet" ->
      Testnet
  | "mainnet" ->
      Mainnet
  | _ ->
      Other_network Node_config.network
