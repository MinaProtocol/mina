(* sql.ml -- SQL queries of the missing blocks guardian *)

module Top_blocks = struct
  (* The [limit] highest blocks, highest first: (state_hash, height). *)
  let query =
    Mina_caqti.collect_req Caqti_type.int
      Caqti_type.(t2 string int)
      {sql| SELECT state_hash, height FROM blocks
            ORDER BY height DESC
            LIMIT $1
      |sql}

  let run (module Conn : Mina_caqti.CONNECTION) limit =
    Conn.collect_list query limit
end
