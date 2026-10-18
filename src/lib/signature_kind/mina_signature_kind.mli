type t = Mina_signature_kind_type.t =
  | Testnet
  | Mainnet
  | Other_network of string
[@@deriving bin_io, to_yojson]

(** Render the signature kind for use in constructing directory names. *)
val to_directory_name : t -> string

(** The Mina_signature_kind_type in the compiled config. Deprecated - will be
    replaced by a runtime-derived value. *)
val t_DEPRECATED : t
