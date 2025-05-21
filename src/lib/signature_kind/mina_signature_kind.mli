type t = Mina_signature_kind_type.t =
  | Testnet
  | Mainnet
  | Other_network of string

(** The Mina_signature_kind_type in the compiled config. Deprecated - will be
    replaced by a runtime-derived value. *)
val t_DEPRECATED : t
