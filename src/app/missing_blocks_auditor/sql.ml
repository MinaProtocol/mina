(* sql.ml -- (Postgresql) SQL queries for missing blocks auditor *)

module Unparented_blocks = struct
  (* parent_hashes represent ends of chains leading to an orphan block *)

  let query =
    Mina_caqti.collect_req Caqti_type.unit
      Caqti_type.(t4 int string int string)
      {sql|
           SELECT id, state_hash, height, parent_hash FROM blocks
           WHERE parent_id IS NULL
      |sql}

  let run (module Conn : Mina_caqti.CONNECTION) () = Conn.collect_list query ()
end

module Missing_blocks_gap = struct
  let query =
    Mina_caqti.find_req Caqti_type.int Caqti_type.int
      {sql| SELECT $1 - MAX(height) - 1 FROM blocks
            WHERE height < $1
      |sql}

  let run (module Conn : Mina_caqti.CONNECTION) height = Conn.find query height
end

module Chain_status = struct
  let query_highest_canonical =
    Mina_caqti.find_req Caqti_type.unit Caqti_type.int64
      {sql| SELECT max(height) FROM blocks
            WHERE chain_status = 'canonical'
      |sql}

  let run_highest_canonical (module Conn : Mina_caqti.CONNECTION) () =
    Conn.find query_highest_canonical ()

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
