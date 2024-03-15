(* pg_data.ml -- Postgres data *)

let query_connection_count =
  Caqti_request.find Caqti_type.unit Caqti_type.int64
    {sql| SELECT count(*) FROM pg_stat_activity
              WHERE state = 'active'
        |sql}

let run_connection_count (module Conn : Caqti_async.CONNECTION) =
  Conn.find query_connection_count

let query_lock_count =
  Caqti_request.find Caqti_type.unit Caqti_type.int64
    {sql| SELECT count(*) FROM pg_locks
              WHERE mode = 'SIReadLock'
        |sql}

let run_lock_count (module Conn : Caqti_async.CONNECTION) =
  Conn.find query_lock_count
