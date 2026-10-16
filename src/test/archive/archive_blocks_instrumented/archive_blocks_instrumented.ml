(* archive_blocks_instrumented -- archive_blocks with a statement probe.

   Test build only: the production archive_blocks binary is archive_blocks_lib
   with no hooks. This executable runs the same CLI with a probe attached, for
   archive_memory_bench.

   [pg_prepared_statements] lists only the statements of the session that runs
   the query. The probe runs on the ingest's own pool connection, so with a
   one-connection pool (CAQTI_POOL_MAX_SIZE=1) it reads the session that writes
   the blocks. When ARCHIVE_BLOCKS_PREPARED_STATEMENTS_FILE is set, it appends
   one line per block, [block <n> <statements> <distinct texts>], and after the
   last block one [duplicate <count> <statement>] line for each SQL text
   prepared more than once. When it is unset, the probe does nothing. *)

open Core
open Async

let statements_file_env = "ARCHIVE_BLOCKS_PREPARED_STATEMENTS_FILE"

let prepared_statements_count_req =
  Mina_caqti.find_req Caqti_type.unit
    Caqti_type.(t2 int int)
    "SELECT count(*)::int, count(DISTINCT statement)::int FROM \
     pg_prepared_statements"

let duplicate_prepared_statements_req =
  Mina_caqti.collect_req Caqti_type.unit
    Caqti_type.(t2 int string)
    "SELECT count(*)::int, regexp_replace(statement, '\\s+', ' ', 'g') FROM \
     pg_prepared_statements GROUP BY statement HAVING count(*) > 1 ORDER BY 1 \
     DESC, 2 LIMIT 10"

(* Runs [f] on the pool; logs and returns [None] if the query fails *)
let use ~pool ~logger f =
  match%map Mina_caqti.Pool.use f pool with
  | Ok x ->
      Some x
  | Error err ->
      [%log error] "Could not read pg_prepared_statements"
        ~metadata:[ ("error", `String (Caqti_error.show err)) ] ;
      None

let append_lines path lines =
  Out_channel.with_file ~append:true path ~f:(fun out ->
      Out_channel.output_lines out lines ;
      Out_channel.flush out )

let after_block ~pool ~logger n =
  match Sys.getenv statements_file_env with
  | None ->
      Deferred.unit
  | Some path ->
      let%map counts =
        use ~pool ~logger (fun (module Conn : Mina_caqti.CONNECTION) ->
            Conn.find prepared_statements_count_req () )
      in
      Option.iter counts ~f:(fun (total, distinct) ->
          append_lines path [ sprintf "block %d %d %d" n total distinct ] )

let finish ~pool ~logger =
  match Sys.getenv statements_file_env with
  | None ->
      Deferred.unit
  | Some path ->
      let%map duplicates =
        use ~pool ~logger (fun (module Conn : Mina_caqti.CONNECTION) ->
            Conn.collect_list duplicate_prepared_statements_req () )
      in
      Option.iter duplicates ~f:(fun rows ->
          append_lines path
            (List.map rows ~f:(fun (count, statement) ->
                 sprintf "duplicate %d %s" count statement ) ) )

let () = Archive_blocks_lib.run ~after_block ~finish ()
