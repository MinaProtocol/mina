(* prepared_statements_probe.ml

   Measures whether archive_blocks builds its database requests once. Caqti
   prepares a statement for each request object on each connection, and keeps
   it for the life of that connection. A request built again on every call
   therefore adds a statement on every call, and the connection's memory grows
   without bound (#18857). The probe reads the count after each block, so the
   growth shows in the output, and it lists each SQL text prepared more than
   once, which names the request that leaks.

   Only archive_blocks --instrumented uses it. It must run on the connection
   that writes the blocks, so the pool must hold one connection
   (CAQTI_POOL_MAX_SIZE=1). pg_prepared_statements shows only the statements of
   the session that runs the query.

   Output: one line [block <n> <statements> <distinct texts>] per block, then
   one [duplicate <count> <statement>] line per SQL text prepared more than
   once. *)

open Core_kernel
open Async

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

let after_block ~pool ~logger ~path n =
  let%map counts =
    use ~pool ~logger (fun (module Conn : Mina_caqti.CONNECTION) ->
        Conn.find prepared_statements_count_req () )
  in
  Option.iter counts ~f:(fun (total, distinct) ->
      append_lines path [ sprintf "block %d %d %d" n total distinct ] )

let finish ~pool ~logger ~path =
  let%map duplicates =
    use ~pool ~logger (fun (module Conn : Mina_caqti.CONNECTION) ->
        Conn.collect_list duplicate_prepared_statements_req () )
  in
  Option.iter duplicates ~f:(fun rows ->
      append_lines path
        (List.map rows ~f:(fun (count, statement) ->
             sprintf "duplicate %d %s" count statement ) ) )
