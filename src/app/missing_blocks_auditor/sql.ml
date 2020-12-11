(* sql.ml -- (Postgresql) SQL queries for missing blocks auditor *)

module Unparented_blocks = struct
  (* parent_hashes represent ends of chains leading to an orphan block *)

  let query =
    Caqti_request.collect Caqti_type.unit
      Caqti_type.(tup3 int string string)
      {|
           SELECT id,state_hash,parent_hash FROM blocks
           WHERE parent_id IS NULL
      |}

  let run (module Conn : Caqti_async.CONNECTION) () =
    Conn.collect_list query ()
end
