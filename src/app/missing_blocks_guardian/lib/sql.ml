(* sql.ml -- (Postgresql) SQL queries for the missing blocks guardian. *)

module Max_block_height = struct
  (* Highest block height held by the archive, 0 when it holds none.  Used
     only to report the archive's state before and after a pass. *)

  let query =
    Mina_caqti.find_req Caqti_type.unit Caqti_type.int
      {sql| SELECT COALESCE(MAX(height), 0) FROM blocks |sql}

  let run (module Conn : Mina_caqti.CONNECTION) () = Conn.find query ()
end

module Unparented_blocks_detail = struct
  (* Returns full rows for blocks with no parent -- used by the audit to
     report each orphan. *)

  let query =
    Mina_caqti.collect_req Caqti_type.unit
      Caqti_type.(t4 int string int string)
      {sql|
           SELECT id, state_hash, height, parent_hash FROM blocks
           WHERE parent_id IS NULL
      |sql}

  let run (module Conn : Mina_caqti.CONNECTION) () = Conn.collect_list query ()
end

module GenesisOrFirstForkBlockHeight = struct
  (* The genesis block -- or, on a forked network, the first block after the
     hard fork -- legitimately has no parent in the archive.  It must never be
     reported as missing, and the guardian must never try to download its
     parent.

     This returns [None] when the archive holds no such block.  The auditor
     this app replaces used a [find] request here, so an archive restored from
     a dump that does not reach back to genesis failed with an opaque Caqti
     "expected one row" error.  Reporting the absence explicitly lets the
     caller say what is actually wrong. *)

  let query =
    Mina_caqti.find_opt_req Caqti_type.unit Caqti_type.int
      {sql| SELECT height FROM blocks
            WHERE parent_id IS NULL
            AND global_slot_since_hard_fork = 0
            AND chain_status = 'canonical'
            ORDER BY height ASC
            LIMIT 1
      |sql}

  let run (module Conn : Mina_caqti.CONNECTION) () = Conn.find_opt query ()
end

module Missing_blocks_gap = struct
  (* How many block heights lie between the given block and the highest block
     below it.

     [MAX(height)] is SQL NULL when the archive holds nothing below this block,
     which makes the whole expression NULL.  The auditor this app replaces
     decoded the result as a plain [int], so on any archive whose lowest block
     is not a canonical genesis block it died with

       Cannot decode int from <...>: Invalid value "".

     naming neither the block nor the reason.  [None] here means "there is no
     block below this one at all", which the caller reports as such. *)

  let query =
    Mina_caqti.find_req Caqti_type.int
      Caqti_type.(option int)
      {sql| SELECT $1 - MAX(height) - 1 FROM blocks
            WHERE height < $1
      |sql}

  let run (module Conn : Mina_caqti.CONNECTION) height = Conn.find query height
end

module Block_count = struct
  (* Used by the pre-flight check.  An archive whose [blocks] table cannot be
     read at all has a configuration or schema problem, not a missing-block
     problem, and must be reported as such before any download starts. *)

  let query =
    Mina_caqti.find_req Caqti_type.unit Caqti_type.int64
      {sql| SELECT count(*) FROM blocks |sql}

  let run (module Conn : Mina_caqti.CONNECTION) () = Conn.find query ()
end

module Chain_status = struct
  (* The chain-status gap check runs in two steps:

     1. [run_highest_canonical] -- the height of the chain tip we trust.
        [None] when the archive holds no canonical block at all.  We
        deliberately do not [COALESCE(MAX(height), 0)] here: a height of 0
        cannot be told apart from a genuine genesis-only chain, and the audit
        must report "canonicalization has never run" as the distinct problem
        it is.  Selecting the top row with [LIMIT 1] makes the empty case
        return zero rows, which [find_opt] gives as [None].
     2. [run_count_pending_below] -- how many blocks at or below that
        canonical height are still [pending].

     In a healthy archive (2) is 0: everything at or below the canonical tip
     should itself be canonical.  A non-zero count means canonicalization
     stalled and the chain-status bookkeeping has a gap. *)

  let query_highest_canonical =
    Mina_caqti.find_opt_req Caqti_type.unit Caqti_type.int64
      {sql| SELECT height FROM blocks
            WHERE chain_status = 'canonical'
            ORDER BY height DESC
            LIMIT 1
      |sql}

  let run_highest_canonical (module Conn : Mina_caqti.CONNECTION) () =
    Conn.find_opt query_highest_canonical ()

  let query_count_pending_below =
    Mina_caqti.find_req Caqti_type.int64 Caqti_type.int64
      {sql| SELECT count(*) FROM blocks
            WHERE chain_status = 'pending'
            AND height <= ?
      |sql}

  let run_count_pending_below (module Conn : Mina_caqti.CONNECTION) height =
    Conn.find query_count_pending_below height

  let query_canonical_chain =
    Mina_caqti.collect_req Caqti_type.int64
      Caqti_type.(t3 int string string)
      {sql| WITH RECURSIVE chain AS (

               (SELECT id, state_hash, parent_id, chain_status

                FROM blocks b
                WHERE height = $1
                AND chain_status = 'canonical')

                UNION ALL

                SELECT b.id, b.state_hash, b.parent_id, b.chain_status

                FROM blocks b
                INNER JOIN chain
                ON b.id = chain.parent_id AND chain.id <> chain.parent_id
               )

              SELECT id,state_hash,chain_status
              FROM chain
              ORDER BY id ASC
      |sql}

  let run_canonical_chain (module Conn : Mina_caqti.CONNECTION) height =
    Conn.collect_list query_canonical_chain height
end
