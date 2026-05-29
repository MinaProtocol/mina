(** Shared SQL queries for archive node health monitoring.

    These queries are used by the archive healthcheck CLI, the
    missing blocks auditor, and archive metrics reporting. *)

(** Maximum block height stored in the archive database.
    Returns 0 if the database is empty. *)
module Max_block_height : sig
  val run :
       (module Mina_caqti.CONNECTION)
    -> unit
    -> (int, [> Caqti_error.call_or_retrieve ]) result Async.Deferred.t
end

(** Count of missing blocks (height gaps) within a sliding window
    of the most recent [missing_blocks_width] blocks. *)
module Missing_blocks_count : sig
  val run :
       (module Mina_caqti.CONNECTION)
    -> missing_blocks_width:int
    -> unit
    -> (int, [> Caqti_error.call_or_retrieve ]) result Async.Deferred.t
end

(** Count of blocks with no parent in the database (orphaned blocks). *)
module Unparented_blocks_count : sig
  val run :
       (module Mina_caqti.CONNECTION)
    -> unit
    -> (int, [> Caqti_error.call_or_retrieve ]) result Async.Deferred.t
end

(** Timestamp of the most recent block (as a string of milliseconds
    since epoch), or [None] if the database is empty. *)
module Latest_block_timestamp : sig
  val run :
       (module Mina_caqti.CONNECTION)
    -> unit
    -> (string option, [> Caqti_error.call_or_retrieve ]) result
       Async.Deferred.t
end

(** Maximum height among blocks with [chain_status = 'canonical'].
    Returns 0L if no canonical blocks exist. *)
module Highest_canonical_height : sig
  val run :
       (module Mina_caqti.CONNECTION)
    -> unit
    -> (int64, [> Caqti_error.call_or_retrieve ]) result Async.Deferred.t
end

(** Count of pending blocks at or below the given height. *)
module Pending_blocks_below_canonical : sig
  val run :
       (module Mina_caqti.CONNECTION)
    -> int64
    -> (int64, [> Caqti_error.call_or_retrieve ]) result Async.Deferred.t
end
