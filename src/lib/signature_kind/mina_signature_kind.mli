type t = Mina_signature_kind_type.t =
  | Testnet
  | Mainnet
  | Other_network of string

val t : t
