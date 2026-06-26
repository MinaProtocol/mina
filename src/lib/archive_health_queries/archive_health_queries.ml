(* archive_health_queries.ml -- shared SQL queries for archive node health *)

module Max_block_height = struct
  let query =
    Mina_caqti.find_req Caqti_type.unit Caqti_type.int
      "SELECT COALESCE(MAX(height), 0) FROM blocks"

  let run (module Conn : Mina_caqti.CONNECTION) () = Conn.find query ()
end

module Missing_blocks_count = struct
  (* Count heights with no block row inside a sliding window ending at
     the chain tip.  The window's lower bound is clamped to the lowest
     block actually present ([MIN(height)]), NOT to height 1: in a
     hardfork archive the earliest block is the fork genesis (e.g.
     height 296372) and nothing exists below it, so heights below
     [MIN(height)] are not "missing" — they simply predate this
     archive.  This keeps the count consistent with
     missing_blocks_guardian, which only looks for gaps within the
     range of blocks the archive actually holds.

     The count is computed purely arithmetically: the number of heights
     in the window ([window_end - window_start + 1]) minus the number of
     blocks actually present in that range.  This avoids materialising a
     [generate_series] row per height and the LEFT JOIN against it.  On
     an empty [blocks] table [MIN]/[MAX] are NULL, so the whole
     expression is NULL; the outer [COALESCE(..., 0)] keeps the
     mli contract (returns 0, never NULL). *)
  let query missing_blocks_width =
    Mina_caqti.find_req Caqti_type.unit Caqti_type.int
      (Core_kernel.sprintf
         {sql|
        WITH extremes AS (
          SELECT MIN(height) AS min_block, MAX(height) AS max_block
          FROM blocks
        ), window_bounds AS (
          SELECT GREATEST(min_block, max_block - %d) AS window_start,
                 max_block AS window_end
          FROM extremes
        )
        SELECT COALESCE(
                 (window_end - window_start + 1)
                 - (SELECT COUNT(*) FROM blocks
                    WHERE height BETWEEN window_start AND window_end),
                 0)::int AS missing_blocks
        FROM window_bounds
      |sql}
         missing_blocks_width )

  let run (module Conn : Mina_caqti.CONNECTION) ~missing_blocks_width () =
    Conn.find (query missing_blocks_width) ()
end

module Unparented_blocks_count = struct
  (* Count blocks whose parent row is absent, EXCLUDING the earliest
     block in the archive.  The earliest block ([MIN(height)] — the
     genesis on a fresh chain, or the fork genesis on a hardfork
     archive) legitimately has [parent_id IS NULL] because its parent
     belongs to the pre-fork chain and is not stored here.  Counting it
     would make every healthy archive report one permanent "orphan", so
     we exclude it and count only genuinely unparented blocks above the
     earliest height. *)
  let query =
    Mina_caqti.find_req Caqti_type.unit Caqti_type.int
      {sql| SELECT COUNT(*) FROM blocks
            WHERE parent_id IS NULL
            AND height > (SELECT MIN(height) FROM blocks) |sql}

  let run (module Conn : Mina_caqti.CONNECTION) () = Conn.find query ()
end

module Latest_block_timestamp = struct
  let query =
    Mina_caqti.find_opt_req Caqti_type.unit Caqti_type.string
      {sql| SELECT timestamp FROM blocks ORDER BY height DESC LIMIT 1 |sql}

  let run (module Conn : Mina_caqti.CONNECTION) () = Conn.find_opt query ()
end

module Highest_canonical_height = struct
  (* Highest height among canonical blocks, or [None] when the archive
     holds no canonical block yet.  We deliberately do NOT
     [COALESCE(MAX(height), 0)]: a height of 0 is indistinguishable from
     a genuine genesis-only chain, and callers (e.g. the missing-blocks
     auditor) need to tell "no canonical chain" apart from "canonical
     chain tops out at height 0".  Selecting the top row with [LIMIT 1]
     rather than [MAX] makes the empty case return zero rows, which
     [find_opt] surfaces as [None] — mirroring [Latest_block_timestamp]. *)
  let query =
    Mina_caqti.find_opt_req Caqti_type.unit Caqti_type.int64
      {sql| SELECT height FROM blocks
            WHERE chain_status = 'canonical'
            ORDER BY height DESC
            LIMIT 1 |sql}

  let run (module Conn : Mina_caqti.CONNECTION) () = Conn.find_opt query ()
end

module Pending_blocks_below_canonical = struct
  let query =
    Mina_caqti.find_req Caqti_type.int64 Caqti_type.int64
      {sql| SELECT COUNT(*) FROM blocks
            WHERE chain_status = 'pending'
            AND height <= ? |sql}

  let run (module Conn : Mina_caqti.CONNECTION) height = Conn.find query height
end
