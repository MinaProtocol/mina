(* pg_memory/main.ml -- postgres memory-usage benchmark for Mina_caqti.

   Several helpers in {!Mina_caqti} build a fresh [Caqti_request.t] on every
   call (the SQL text is derived from runtime [~table_name]/[~cols] arguments).
   Caqti keys its per-connection prepared-statement cache by request-object
   identity, so a fresh request per call makes the PostgreSQL backend register
   a new server-side prepared statement (PREPARE _caqtiN) that lives for the
   lifetime of the connection. On the archive's long-lived pooled connections
   these accumulate without bound and OOM the postgres backend (see
   MinaProtocol/mina#18857).

   This tool drives a chosen helper N times on a single long-lived connection
   and, on that same connection, samples:
     - [pg_prepared_statements]        -> exact server-side prepared-stmt count
     - [pg_backend_memory_contexts]    -> backend cache/plan memory (PG14+)
   On unfixed code the prepared-statement count grows ~linearly with the number
   of calls; once the offending requests are marked [~oneshot:true] (or hoisted
   to module level) it stays flat. The tool is therefore both a reproduction of
   the leak and a regression guard (see [--assert-max-prepared]).

   Results can additionally be emitted as InfluxDB line protocol
   ([--influxdb-file]) using the same measurement/tag convention as
   scripts/tests/rosetta-load.sh, so runs can be tracked on the perf infra.

   It needs a live PostgreSQL. Pass [--uri] or set [MINA_CAQTI_TEST_PG_URI];
   with neither, it prints a skip notice and exits 0 so it is a no-op in
   environments without a database. *)

open Core
open Async

let ok_exn ~ctx = function
  | Ok x ->
      x
  | Error e ->
      failwithf "%s: %s" ctx (Caqti_error.show e) ()

(* Instrumentation / DDL requests are marked [~oneshot:true] so that running
   them does NOT itself add to the prepared-statement count we are measuring. *)
let exec_oneshot sql =
  Caqti_request.Infix.(Caqti_type.unit ->. Caqti_type.unit) ~oneshot:true sql

let count_prepared_req =
  Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.int)
    ~oneshot:true "SELECT count(*)::int FROM pg_prepared_statements"

let server_version_num_req =
  Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.int)
    ~oneshot:true "SELECT current_setting('server_version_num')::int"

(* Whole-backend private memory. Cached query plans live under CacheMemoryContext
   as child contexts (CachedPlanSource / CachedPlan), so the total tracks the
   leak; we report it in KiB as a secondary, corroborating signal to the
   deterministic prepared-statement count. [pg_backend_memory_contexts] only
   exists on PostgreSQL 14+, so callers must gate on the server version and
   report 0 where it is unavailable (the prepared-statement count remains the
   primary, version-independent signal). *)
let backend_bytes_req =
  Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.int)
    ~oneshot:true
    "SELECT coalesce(sum(total_bytes), 0)::bigint FROM \
     pg_backend_memory_contexts"

module Conn_ops = struct
  (* small helpers over a first-class CONNECTION module *)
  let exec (module C : Mina_caqti.CONNECTION) req arg =
    C.exec req arg >>| ok_exn ~ctx:"exec"

  let get_int (module C : Mina_caqti.CONNECTION) req =
    C.find req () >>| ok_exn ~ctx:"find"

  let ddl conn sql = exec conn (exec_oneshot sql) ()

  (* PG14+ only; report 0 on older servers (pg_backend_memory_contexts absent) *)
  let has_backend_memory_contexts conn =
    get_int conn server_version_num_req >>| fun v -> v >= 140000

  let sample ~has_memctx conn =
    let%bind prepared = get_int conn count_prepared_req in
    let%map bytes =
      if has_memctx then get_int conn backend_bytes_req else return 0
    in
    (prepared, bytes)

  let disconnect (module C : Mina_caqti.CONNECTION) = C.disconnect ()
end

type result =
  { name : string
  ; prepared_final : int
  ; per_call : float
  ; backend_kib_final : int
  ; iterations : int
  }

type scenario =
  { name : string
  ; ddl : string list (* DROP/CREATE statements run before the loop *)
  ; step : (module Mina_caqti.CONNECTION) -> int -> unit Deferred.t
        (* one unit of work exercising a single helper, using a fresh request *)
  ; fixed_by : string (* which PR is expected to neutralise this scenario *)
  }

(* --- the helpers under test ------------------------------------------------

   Every scenario uses a text column so the exact same source compiles against
   develop, #18858 and #18860 (the latter changed insert_multi_into_col's
   [values] from [string list] to ['col list]; with a string column ['col =
   string] the call is unchanged). *)

let scenarios : scenario list =
  [ { name = "select_insert_into_cols"
    ; fixed_by = "#18858 (~oneshot:true)"
    ; ddl =
        [ "DROP TABLE IF EXISTS mb_sic"
        ; "CREATE TABLE mb_sic (id serial PRIMARY KEY, k text UNIQUE)"
        ]
    ; step =
        (fun conn i ->
          (* distinct key each call -> SELECT miss then INSERT: exercises BOTH
             of the requests this helper builds per call *)
          Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
            ~table_name:"mb_sic"
            ~cols:([ "k" ], Caqti_type.string)
            conn (sprintf "k-%d" i)
          >>| ok_exn ~ctx:"select_insert_into_cols"
          >>| ignore )
    }
  ; { name = "insert_multi_into_col"
    ; fixed_by = "#18860 (parameter binding) / #18858 (~oneshot:true)"
    ; ddl =
        [ "DROP TABLE IF EXISTS mb_imc"
        ; "CREATE TABLE mb_imc (id serial PRIMARY KEY, v text UNIQUE)"
        ]
    ; step =
        (fun conn i ->
          (* single-element list keeps the VALUES/IN list length constant so we
             isolate the request-identity effect from SQL-text variation *)
          Mina_caqti.insert_multi_into_col ~table_name:"mb_imc"
            ~col:("v", Caqti_type.string) conn
            [ sprintf "v-%d" i ]
          >>| ok_exn ~ctx:"insert_multi_into_col"
          >>| ignore )
    }
  ; { name = "upsert_into_cols_returning"
    ; fixed_by = "NEITHER PR (residual leak — runs every block)"
    ; ddl =
        [ "DROP TABLE IF EXISTS mb_upsert"
        ; "CREATE TABLE mb_upsert (id serial PRIMARY KEY, k text UNIQUE)"
        ]
    ; step =
        (fun conn i ->
          Mina_caqti.upsert_into_cols_returning ~on_conflict:"k"
            ~returning:("id", Caqti_type.int) ~table_name:"mb_upsert"
            ~cols:([ "k" ], Caqti_type.string)
            conn (sprintf "k-%d" i)
          >>| ok_exn ~ctx:"upsert_into_cols_returning"
          >>| ignore )
    }
  ]

let run_scenario ~uri ~iterations ~sample_every (s : scenario) =
  let%bind conn =
    Mina_caqti.connect uri >>| ok_exn ~ctx:(sprintf "connect[%s]" s.name)
  in
  let%bind () =
    Deferred.List.iter s.ddl ~f:(fun sql -> Conn_ops.ddl conn sql)
  in
  let%bind has_memctx = Conn_ops.has_backend_memory_contexts conn in
  printf "\n== scenario: %s ==\n" s.name ;
  printf "   expected fix: %s\n" s.fixed_by ;
  if not has_memctx then
    printf
      "   (note: pg_backend_memory_contexts unavailable on this server \
       (<PG14); backend_KiB reported as 0)\n" ;
  printf "   %-10s %-12s %-14s\n" "calls" "prepared" "backend_KiB" ;
  let sample_and_print calls =
    let%map prepared, bytes = Conn_ops.sample ~has_memctx conn in
    printf "   %-10d %-12d %-14d\n" calls prepared (bytes / 1024) ;
    (prepared, bytes)
  in
  let%bind prepared0, _ = sample_and_print 0 in
  let%bind final_prepared, final_bytes =
    Deferred.List.fold
      (List.range 1 (iterations + 1))
      ~init:(prepared0, 0)
      ~f:(fun acc i ->
        let%bind () = s.step conn i in
        if i % sample_every = 0 || i = iterations then sample_and_print i
        else return acc )
  in
  let%bind () = Conn_ops.disconnect conn in
  let per_call = Float.of_int final_prepared /. Float.of_int iterations in
  let backend_kib_final = final_bytes / 1024 in
  printf
    "   RESULT scenario=%s iterations=%d prepared_final=%d \
     prepared_per_call=%.3f backend_KiB_final=%d\n"
    s.name iterations final_prepared per_call backend_kib_final ;
  return
    { name = s.name
    ; prepared_final = final_prepared
    ; per_call
    ; backend_kib_final
    ; iterations
    }

(* --- InfluxDB line protocol (matches scripts/tests/rosetta-load.sh) --------- *)

(* line-protocol tag/measurement values must not contain unescaped spaces or
   commas; keep it simple and sanitise to underscores *)
let sanitize s =
  String.map s ~f:(fun c -> match c with ' ' | ',' | '=' -> '_' | c -> c)

let influx_lines ~measurement ~tags (results : result list) =
  let ts_ns = Time_ns.now () |> Time_ns.to_int_ns_since_epoch in
  let tag_str =
    List.map tags ~f:(fun (k, v) -> sprintf "%s=%s" k (sanitize v))
    |> String.concat ~sep:","
  in
  List.map results ~f:(fun r ->
      sprintf
        "%s,%s,scenario=%s \
         prepared_final=%di,prepared_per_call=%.6f,backend_kib_final=%di,iterations=%di \
         %d"
        (sanitize measurement) tag_str (sanitize r.name) r.prepared_final
        r.per_call r.backend_kib_final r.iterations ts_ns )

let main ~uri ~iterations ~sample_every ~assert_max_prepared ~influxdb_file
    ~measurement ~tags () =
  printf "mina_caqti postgres memory-usage benchmark\n" ;
  printf "uri=%s iterations=%d sample_every=%d\n" (Uri.to_string uri) iterations
    sample_every ;
  let%bind results =
    Deferred.List.map scenarios ~f:(run_scenario ~uri ~iterations ~sample_every)
  in
  printf "\n== summary ==\n" ;
  List.iter results ~f:(fun r ->
      printf "   %-28s prepared_final=%-8d per_call=%.3f\n" r.name
        r.prepared_final r.per_call ) ;
  let lines = influx_lines ~measurement ~tags results in
  ( match influxdb_file with
  | None ->
      ()
  | Some path ->
      Out_channel.write_lines path lines ;
      printf "\n== influxdb line protocol -> %s ==\n" path ;
      List.iter lines ~f:(fun l -> printf "   %s\n" l) ) ;
  ( match assert_max_prepared with
  | None ->
      ()
  | Some limit ->
      let offenders =
        List.filter results ~f:(fun r -> r.prepared_final > limit)
      in
      if not (List.is_empty offenders) then (
        eprintf
          "\n\
           FAIL: %d scenario(s) exceeded --assert-max-prepared=%d (memory \
           regression):\n"
          (List.length offenders) limit ;
        List.iter offenders ~f:(fun r ->
            eprintf "   %s: prepared_final=%d\n" r.name r.prepared_final ) ;
        Core.exit 1 )
      else printf "\nOK: all scenarios <= --assert-max-prepared=%d\n" limit ) ;
  return ()

let () =
  Command.async
    ~summary:
      "Measure Mina_caqti per-connection prepared-statement count and postgres \
       backend memory"
    (let%map_open.Command uri =
       flag "--uri" (optional string)
         ~doc:"URI postgres connection (else $MINA_CAQTI_TEST_PG_URI)"
     and iterations =
       flag "--iterations"
         (optional_with_default 2000 int)
         ~doc:"N calls per scenario (default 2000)"
     and sample_every =
       flag "--sample-every" (optional int)
         ~doc:"M sample cadence (default iterations/10)"
     and assert_max_prepared =
       flag "--assert-max-prepared" (optional int)
         ~doc:"K fail if any scenario's final prepared count exceeds K"
     and influxdb_file =
       flag "--influxdb-file" (optional string)
         ~doc:"PATH write InfluxDB line protocol (one point per scenario) here"
     and measurement =
       flag "--measurement"
         (optional_with_default "mina_caqti_pg_memory_bench" string)
         ~doc:"NAME InfluxDB measurement name"
     and variant =
       flag "--variant" (optional string)
         ~doc:"V tag runs (e.g. baseline/pr18858); else $MINA_BENCH_VARIANT"
     and network =
       flag "--network" (optional string) ~doc:"NET optional network tag"
     and git_branch =
       flag "--git-branch" (optional string)
         ~doc:"B branch tag (else $GIT_BRANCH, else git)"
     and git_commit =
       flag "--git-commit" (optional string)
         ~doc:"C commit tag (else $GIT_COMMIT, else git)"
     in
     fun () ->
       let uri_str =
         match uri with
         | Some u ->
             Some u
         | None ->
             Sys.getenv "MINA_CAQTI_TEST_PG_URI"
       in
       match uri_str with
       | None ->
           printf
             "SKIP: no --uri and $MINA_CAQTI_TEST_PG_URI unset; nothing to do.\n" ;
           return ()
       | Some u ->
           let iterations = Int.max 1 iterations in
           let sample_every =
             match sample_every with
             | Some m when m > 0 ->
                 m
             | _ ->
                 Int.max 1 (iterations / 10)
           in
           let env_or v key =
             match v with Some _ -> v | None -> Sys.getenv key
           in
           let opt_tag k = function None -> [] | Some v -> [ (k, v) ] in
           let tags =
             opt_tag "branch"
               (Option.first_some
                  (env_or git_branch "GIT_BRANCH")
                  (Some "unknown") )
             @ opt_tag "commit"
                 (Option.first_some
                    (env_or git_commit "GIT_COMMIT")
                    (Some "unknown") )
             @ opt_tag "variant"
                 (Option.first_some
                    (env_or variant "MINA_BENCH_VARIANT")
                    (Some "unknown") )
             @ opt_tag "network" network
           in
           main ~uri:(Uri.of_string u) ~iterations ~sample_every
             ~assert_max_prepared ~influxdb_file ~measurement ~tags () )
  |> Command_unix.run
