(* sql.ml -- (Postgresql) SQL queries for missing blocks auditor *)

module Unparented_blocks = struct
  (* parent_hashes represent ends of chains leading to an orphan block *)

  let query =
    Caqti_request.collect Caqti_type.unit
      Caqti_type.(tup4 int string int string)
      {sql|
           SELECT id, state_hash, height, parent_hash FROM blocks
           WHERE parent_id IS NULL
      |sql}

  let run (module Conn : Caqti_async.CONNECTION) () = Conn.collect_list query ()
end

module Chain_status = struct
  let query_highest_canonical =
    Caqti_request.find Caqti_type.unit Caqti_type.int64
      {sql| SELECT max(height) FROM blocks
            WHERE chain_status = 'canonical'
      |sql}

  let run_highest_canonical (module Conn : Caqti_async.CONNECTION) () =
    Conn.find query_highest_canonical ()

  let query_count_pending_below =
    Caqti_request.find Caqti_type.int64 Caqti_type.int64
      {sql| SELECT count(*) FROM blocks
            WHERE chain_status = 'pending'
            AND height <= ?
      |sql}

  let run_count_pending_below (module Conn : Caqti_async.CONNECTION) height =
    Conn.find query_count_pending_below height
end
