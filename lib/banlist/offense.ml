(* TODO: add more offenses. See https://github.com/o1-labs/nanobit/issues/852 *)

type t = Send_bad_hash | Send_bad_aux | Failed_to_connect [@@deriving eq]
