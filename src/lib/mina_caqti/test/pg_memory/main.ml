(* pg_memory/main.ml -- postgres memory-usage benchmark for Mina_caqti.

   Several helpers in {!Mina_caqti} build a fresh [Caqti_request.t] on every
   call (the SQL text is derived from runtime [~table_name]/[~cols] arguments).
   Caqti keys its per-connection prepared-statement cache by request-object
   identity, so a fresh request per call makes the PostgreSQL backend register
   a new server-side prepared statement (PREPARE _caqtiN) that lives for the
   lifetime of the connection. On the archive's long-lived pooled connections
   these accumulate without bound and OOM the postgres backend.

   This tool drives a chosen helper N times on a single long-lived connection
   and, on that same connection, samples:
     - [pg_prepared_statements]        -> exact server-side prepared-stmt count
     - [pg_backend_memory_contexts]    -> backend cache/plan memory (PG14+)
   On unfixed code the prepared-statement count grows ~linearly with the number
   of calls; once the offending requests are marked [~oneshot:true] (or hoisted
   to module level) it stays flat. The tool is therefore both a reproduction of
   the leak and a regression guard (see [--assert-max-prepared]).

   Each scenario works on its own table, named with a UUID and created fresh:
   the benchmark never drops a table it did not create, and drops the one it did
   on the way out. Column values come from Quickcheck generators seeded per
   (scenario, iteration), so the payloads vary in length and shape from call to
   call while two runs still see the identical sequence — a benchmark whose
   inputs drift is not comparable across builds.

   Results can additionally be emitted as InfluxDB line protocol
   ([--influxdb-file]) using the same measurement/tag convention as
   scripts/tests/rosetta-load.sh, so runs can be tracked on the perf infra.

   It needs a live PostgreSQL. Pass [--uri] or set [MINA_CAQTI_TEST_PG_URI];
   with neither, it prints a skip notice and exits 0 so it is a no-op in
   environments without a database. *)

open Core
open Async

(* Instrumentation / DDL requests are marked [~oneshot:true] so that running
   them does NOT itself add to the prepared-statement count we are measuring. *)
let exec_oneshot sql =
  Caqti_request.Infix.(Caqti_type.unit ->. Caqti_type.unit) ~oneshot:true sql

(* Both signals in one round trip. [sum] is deliberately NOT coalesced: a NULL
   means "nothing to measure" and stays distinguishable from a genuine zero.
   Cached query plans live under CacheMemoryContext as child contexts
   (CachedPlanSource / CachedPlan), so the backend total tracks the leak as a
   secondary, corroborating signal to the deterministic prepared-statement
   count. *)
let sample_req =
  Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.(t2 int (option int)))
    ~oneshot:true
    "SELECT (SELECT count(*)::int FROM pg_prepared_statements), (SELECT \
     sum(total_bytes)::bigint FROM pg_backend_memory_contexts)"

(* [pg_backend_memory_contexts] only exists on PostgreSQL 14+; on older servers
   the query above fails to parse, and this is all we can measure. *)
let prepared_only_req =
  Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.int)
    ~oneshot:true "SELECT count(*)::int FROM pg_prepared_statements"

module Sampler = struct
  (* Whether the backend-memory view exists is discovered by using it, not by
     comparing version numbers: the first failure downgrades the sampler for the
     rest of the run. *)
  type t =
    { conn : (module Mina_caqti.CONNECTION); mutable backend_memory : bool }

  let create conn = { conn; backend_memory = true }

  let prepared_only (module C : Mina_caqti.CONNECTION) =
    C.find prepared_only_req () >>| Mina_caqti.ok_exn ~ctx:"sample"

  let sample t =
    let (module C : Mina_caqti.CONNECTION) = t.conn in
    if t.backend_memory then (
      match%bind C.find sample_req () with
      | Ok (prepared, bytes) ->
          return (prepared, bytes)
      | Error _ ->
          t.backend_memory <- false ;
          printf
            "   (note: pg_backend_memory_contexts unavailable on this server \
             (<PG14); backend_KiB not measured)\n" ;
          prepared_only t.conn >>| fun prepared -> (prepared, None) )
    else prepared_only t.conn >>| fun prepared -> (prepared, None)
end

type result =
  { name : string
  ; prepared_final : int
  ; per_call : float
  ; backend_kib_final : int option
        (* [None] on servers without [pg_backend_memory_contexts] (<PG14) *)
  ; iterations : int
  }

type scenario =
  { name : string
  ; setup : table:string -> string
        (* ONE statement, so the table either exists complete or not at all *)
  ; teardown : table:string -> string
  ; step :
      table:string -> (module Mina_caqti.CONNECTION) -> int -> unit Deferred.t
        (* one unit of work exercising a single helper, using a fresh request *)
  }

(* --- generated payloads ----------------------------------------------------

   [insert_multi_into_col] renders its values into the SQL text as single-quoted
   literals without escaping, so generated tokens stay alphanumeric. The
   iteration index is prefixed to every value that must be unique: a collision
   would silently turn an INSERT into a SELECT hit and change what is being
   measured. *)

let gen_token =
  let open Quickcheck.Generator.Let_syntax in
  let%bind len = Int.gen_incl 3 24 in
  let%map chars = List.gen_with_length len Char.gen_alphanum in
  String.of_char_list chars

let gen_tokens =
  let open Quickcheck.Generator.Let_syntax in
  let%bind n = Int.gen_incl 1 8 in
  List.gen_with_length n gen_token

let generate ~scenario ~iteration gen =
  Quickcheck.random_value
    ~seed:(`Deterministic (sprintf "%s:%d" scenario iteration))
    gen

(* --- the helpers under test ------------------------------------------------

   The invariant under test: a helper driven N times on one connection must NOT
   register an unbounded number of server-side prepared statements — the count
   must stay bounded regardless of N (achieved by request reuse / [~oneshot]).

   The columns are text so the same source stays valid across signature variants
   of these helpers (e.g. [insert_multi_into_col] has taken both a [string list]
   and a ['col list] of values; with a string column ['col = string] the call
   site is identical either way). *)

let scenarios : scenario list =
  [ { name = "select_insert_into_cols"
    ; setup =
        (fun ~table ->
          sprintf
            "CREATE TABLE %s (id serial PRIMARY KEY, k1 text NOT NULL, k2 text \
             NOT NULL, k3 text NOT NULL, UNIQUE (k1, k2, k3))"
            table )
    ; teardown = (fun ~table -> sprintf "DROP TABLE %s" table)
    ; step =
        (fun ~table conn i ->
          (* distinct key each call -> SELECT miss then INSERT: exercises BOTH
             of the requests this helper builds per call *)
          let k2, k3 =
            generate ~scenario:"select_insert_into_cols" ~iteration:i
              (Quickcheck.Generator.both gen_token gen_token)
          in
          Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
            ~table_name:table
            ~cols:([ "k1"; "k2"; "k3" ], Caqti_type.(t3 string string string))
            conn
            (sprintf "k-%d" i, k2, k3)
          >>| Mina_caqti.ok_exn ~ctx:"select_insert_into_cols"
          >>| ignore )
    }
  ; { name = "insert_multi_into_col"
    ; setup =
        (fun ~table ->
          sprintf
            "CREATE TABLE %s (id serial PRIMARY KEY, v text UNIQUE NOT NULL)"
            table )
    ; teardown = (fun ~table -> sprintf "DROP TABLE %s" table)
    ; step =
        (fun ~table conn i ->
          (* a varying number of values per call: the rendered VALUES list is a
             different length every time, which is the realistic shape and keeps
             the SQL text varying independently of request identity *)
          let values =
            generate ~scenario:"insert_multi_into_col" ~iteration:i gen_tokens
            |> List.mapi ~f:(fun j v -> sprintf "v-%d-%d-%s" i j v)
          in
          Mina_caqti.insert_multi_into_col ~table_name:table
            ~col:("v", Caqti_type.string) conn values
          >>| Mina_caqti.ok_exn ~ctx:"insert_multi_into_col"
          >>| ignore )
    }
  ; { name = "upsert_into_cols_returning"
    ; setup =
        (fun ~table ->
          sprintf
            "CREATE TABLE %s (id serial PRIMARY KEY, k1 text NOT NULL, k2 text \
             NOT NULL, payload text NOT NULL, UNIQUE (k1, k2))"
            table )
    ; teardown = (fun ~table -> sprintf "DROP TABLE %s" table)
    ; step =
        (fun ~table conn i ->
          (* every second call reuses the previous key, so the ON CONFLICT DO
             UPDATE branch is exercised as well as the plain insert *)
          let key_index = if i % 2 = 0 then i - 1 else i in
          let payload =
            generate ~scenario:"upsert_into_cols_returning" ~iteration:i
              gen_token
          in
          Mina_caqti.upsert_into_cols_returning ~on_conflict:"k1,k2"
            ~returning:("id", Caqti_type.int) ~table_name:table
            ~cols:
              ([ "k1"; "k2"; "payload" ], Caqti_type.(t3 string string string))
            conn
            (sprintf "k-%d" key_index, sprintf "j-%d" key_index, payload)
          >>| Mina_caqti.ok_exn ~ctx:"upsert_into_cols_returning"
          >>| ignore )
    }
  ]

(* A UUID table name per run: the benchmark only ever drops what it created in
   this process, and a collision surfaces as a failed CREATE rather than as
   somebody else's data disappearing. *)
let fresh_table_name () =
  Uuid_unix.create () |> Uuid.to_string
  |> String.filter ~f:Char.is_alphanum
  |> (fun s -> String.prefix s 16)
  |> sprintf "pg_memory_%s"

let run_scenario ~uri ~iterations ~sample_every (s : scenario) =
  let table = fresh_table_name () in
  let%bind conn =
    Mina_caqti.connect uri
    >>| Mina_caqti.ok_exn ~ctx:(sprintf "connect[%s]" s.name)
  in
  let (module C : Mina_caqti.CONNECTION) = conn in
  let%bind () =
    C.exec (exec_oneshot (s.setup ~table)) ()
    >>| Mina_caqti.ok_exn ~ctx:(sprintf "setup[%s]" s.name)
  in
  let sampler = Sampler.create conn in
  printf "\n== scenario: %s (table %s) ==\n" s.name table ;
  printf "   %-10s %-12s %-14s\n" "calls" "prepared" "backend_KiB" ;
  let sample_and_print calls =
    let%map prepared, bytes = Sampler.sample sampler in
    printf "   %-10d %-12d %-14s\n" calls prepared
      (Option.value_map bytes ~default:"n/a" ~f:(fun b ->
           Int.to_string (b / 1024) ) ) ;
    (prepared, bytes)
  in
  let%bind prepared0, _ = sample_and_print 0 in
  let%bind final_prepared, final_bytes =
    Deferred.List.fold
      (List.range 1 (iterations + 1))
      ~init:(prepared0, None)
      ~f:(fun acc i ->
        let%bind () = s.step ~table conn i in
        if i % sample_every = 0 || i = iterations then sample_and_print i
        else return acc )
  in
  let%bind () =
    C.exec (exec_oneshot (s.teardown ~table)) ()
    >>| Mina_caqti.ok_exn ~ctx:(sprintf "teardown[%s]" s.name)
  in
  let per_call = Float.of_int final_prepared /. Float.of_int iterations in
  let backend_kib_final = Option.map final_bytes ~f:(fun b -> b / 1024) in
  printf
    "   RESULT scenario=%s iterations=%d prepared_final=%d \
     prepared_per_call=%.3f backend_KiB_final=%s\n"
    s.name iterations final_prepared per_call
    (Option.value_map backend_kib_final ~default:"n/a" ~f:Int.to_string) ;
  let%map () = C.disconnect () in
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
  (* [backend_kib_final] is omitted rather than sent as 0 where the server has no
     [pg_backend_memory_contexts]: a constant-zero series charts as a real
     measurement, whereas a missing one is visibly missing. *)
  List.map results ~f:(fun r ->
      let fields =
        [ sprintf "prepared_final=%di" r.prepared_final
        ; sprintf "prepared_per_call=%.6f" r.per_call
        ; sprintf "iterations=%di" r.iterations
        ]
        @ Option.value_map r.backend_kib_final ~default:[] ~f:(fun kib ->
              [ sprintf "backend_kib_final=%di" kib ] )
      in
      sprintf "%s,%s,scenario=%s %s %d" (sanitize measurement) tag_str
        (sanitize r.name)
        (String.concat ~sep:"," fields)
        ts_ns )

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
