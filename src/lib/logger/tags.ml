(* tags.ml -- tags to be added to logging metadata *)

(* tags should be items that are not otherwise easily
   searchable in log message text
*)
type t = Best_tip_changed | Block_received | Block_production | Libp2p
[@@deriving yojson]
