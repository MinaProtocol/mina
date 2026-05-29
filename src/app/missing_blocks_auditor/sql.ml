(* sql.ml -- (Postgresql) SQL queries specific to the missing blocks auditor.
   Common queries (max height, missing count, unparented count, etc.) live in
   {!Archive_health_queries}. *)

module Unparented_blocks_detail = struct
  (* Returns full rows for blocks with no parent — used by the auditor
     to report each orphan.  For a simple count, use
     {!Archive_health_queries.Unparented_blocks_count}. *)

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
  let query =
    Mina_caqti.find_req Caqti_type.unit Caqti_type.int
      {sql| SELECT height FROM blocks
            WHERE parent_id IS NULL
            AND global_slot_since_hard_fork = 0
            AND chain_status = 'canonical'
            ORDER BY height ASC
            LIMIT 1
      |sql}

  let run (module Conn : Mina_caqti.CONNECTION) height = Conn.find query height
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
  let run_highest_canonical db () =
    Archive_health_queries.Highest_canonical_height.run db ()

  let run_count_pending_below db height =
    Archive_health_queries.Pending_blocks_below_canonical.run db height

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
