(* a claimed-to-be empty type with inhabitants *)

type empty = int [@@deriving bin_io, version {empty}]
