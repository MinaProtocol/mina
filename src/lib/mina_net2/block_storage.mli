type t

module Root_block_status : sig
  type t = Partial | Full | Deleting [@@deriving enum]
end

val open_ : logger:Logger.t -> string -> t

val get_status : t -> Consensus.Body_reference.t -> Root_block_status.t option

val read_body :
  t -> Consensus.Body_reference.t -> Staged_ledger_diff.Body.t option
