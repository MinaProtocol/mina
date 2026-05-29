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
     range of blocks the archive actually holds. *)
  let query missing_blocks_width =
    Mina_caqti.find_req Caqti_type.unit Caqti_type.int
      (Core_kernel.sprintf
         {sql|
        SELECT COUNT(*)
        FROM (SELECT h::int FROM generate_series(
                GREATEST((SELECT MIN(height) FROM blocks),
                         (SELECT MAX(height) FROM blocks) - %d),
                (SELECT MAX(height) FROM blocks)) h
              LEFT JOIN blocks b ON h = b.height
              WHERE b.height IS NULL) AS v
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
  let query =
    Mina_caqti.find_req Caqti_type.unit Caqti_type.int64
      {sql| SELECT COALESCE(MAX(height), 0) FROM blocks
            WHERE chain_status = 'canonical' |sql}

  let run (module Conn : Mina_caqti.CONNECTION) () = Conn.find query ()
end

module Pending_blocks_below_canonical = struct
  let query =
    Mina_caqti.find_req Caqti_type.int64 Caqti_type.int64
      {sql| SELECT COUNT(*) FROM blocks
            WHERE chain_status = 'pending'
            AND height <= ? |sql}

  let run (module Conn : Mina_caqti.CONNECTION) height = Conn.find query height
end
