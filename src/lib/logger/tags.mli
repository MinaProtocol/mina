type t = Best_tip_changed | Block_received | Block_production | Libp2p

val to_yojson : t -> Yojson.Safe.t

val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
