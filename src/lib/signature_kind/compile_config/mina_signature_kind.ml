include Mina_signature_kind_type

let t_DEPRECATED =
  match Node_config.network with
  | "testnet" ->
      Testnet
  | "mainnet" ->
      Mainnet
  | _ ->
      Other_network Node_config.network

let t_TEST_DEPRECATED = t_DEPRECATED
