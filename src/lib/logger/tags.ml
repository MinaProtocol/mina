(* tags.ml -- tags to be added to logging metadata *)

(* tags should be items that are not otherwise easily
   searchable in log message text
*)
type t = Block_production | Libp2p [@@deriving yojson]
