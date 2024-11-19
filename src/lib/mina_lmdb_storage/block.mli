open Core_kernel

type t

module Root_block_status : sig
  type t = Partial | Full | Deleting [@@deriving enum, equal]
end

val create : string -> t

val get_status :
     logger:Logger.t
  -> t
  -> Consensus.Body_reference.t
  -> Root_block_status.t option

val read_body :
     t
  -> Consensus.Body_reference.t
  -> ( Mina_block.Body.t
     , [> `Invalid_structure of Error.t | `Non_full | `Tx_failed ] )
     Result.t
