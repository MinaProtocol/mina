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
