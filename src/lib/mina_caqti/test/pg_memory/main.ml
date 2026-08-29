(* pg_memory/main.ml -- postgres memory-usage benchmark for Mina_caqti.

   Several helpers in {!Mina_caqti} build a fresh [Caqti_request.t] on every
   call (the SQL text is derived from runtime [~table_name]/[~cols] arguments).
   Caqti keys its per-connection prepared-statement cache by request-object
   identity, so a fresh request per call makes the PostgreSQL backend register
   a new server-side prepared statement (PREPARE _caqtiN) that lives for the
   lifetime of the connection. On long-lived pooled connections these accumulate
   without bound and grow the backend's memory.

   This tool drives a chosen helper N times on a single long-lived connection
   and, on that same connection, samples:
     - [pg_prepared_statements]        -> exact server-side prepared-stmt count
     - [pg_backend_memory_contexts]    -> backend cache/plan memory (PG14+)
   A helper that builds a request per call makes the count grow ~linearly with
   the number of calls; one that reuses its request, or marks it [~oneshot:true]
   so it is never cached, keeps it flat. [--assert-max-prepared] turns that into
   a regression guard.

   The tables themselves are generated, not hand-written: each helper is
   instantiated over [--shapes] Quickcheck-generated table shapes (column
   count, column names, text/int column types all drawn from generators), and
   the per-call values are drawn per (scenario, iteration). Everything is
   seeded deterministically, so the shapes and payloads vary within a run but
   two runs still see the identical sequence — a benchmark whose inputs drift
   is not comparable across builds.

   Each scenario works on its own table, named with a UUID and created fresh:
   the benchmark never drops a table it did not create, and drops the one it
   did on the way out.

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

(* Both signals in one round trip, read on the connection doing the work --
   [pg_prepared_statements] and [pg_backend_memory_contexts] are both
   session-local, so no outside observer can obtain either.

   The byte figure sums the plan cache alone: every prepared statement adds one
   [CachedPlanSource] context and one [CachedPlanQuery] context under
   CacheMemoryContext, and nothing else does. Summing every context instead
   would fold in roughly a megabyte of execution-time contexts that come and go
   with each query and would swamp a small leak; measured on PostgreSQL 17, the
   filtered figure is exact and perfectly linear, while the unfiltered one is
   not. The parent CacheMemoryContext block is excluded too, being a constant
   512 KiB that only dilutes the rate. The sum is coalesced because an
   unprepared session legitimately matches no context at all. *)
let sample_req =
  Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.(t2 int (option int)))
    ~oneshot:true
    "SELECT (SELECT count(*)::int FROM pg_prepared_statements), (SELECT \
     coalesce(sum(total_bytes), 0)::bigint FROM pg_backend_memory_contexts \
     WHERE name LIKE 'Cached%')"

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
             (<PG14); plan-cache bytes not measured)\n" ;
          prepared_only t.conn >>| fun prepared -> (prepared, None) )
    else prepared_only t.conn >>| fun prepared -> (prepared, None)
end

type result =
  { name : string
  ; prepared_final : int
  ; per_call : float
  ; plan_cache_kib_final : int option
        (* [None] on servers without [pg_backend_memory_contexts] (<PG14) *)
  ; plan_cache_growth_kib : int option
  ; plan_cache_bytes_per_call : float option
  ; iterations : int
  }

type scenario =
  { name : string
  ; describe : string (* human-readable generated table shape *)
  ; setup : table:string -> string
        (* ONE statement, so the table either exists complete or not at all *)
  ; teardown : table:string -> string
  ; step :
      table:string -> (module Mina_caqti.CONNECTION) -> int -> unit Deferred.t
        (* one unit of work exercising a single helper, using a fresh request *)
  }

(* --- generated table shapes and payloads -----------------------------------

   A shape is a list of columns, each with a generated name and a generated
   type (text or int). The heterogeneous row value is packed into a nested
   [Caqti_type.t2] product built at runtime and hidden behind an existential,
   so the same code drives helpers over tables of any generated width.

   [insert_multi_into_col] renders its values into the SQL text as
   single-quoted literals without escaping, so generated tokens stay
   alphanumeric. The iteration index is prefixed to every value that must be
   unique: a collision would silently turn an INSERT into a SELECT hit and
   change what is being measured. *)

type col_ty = Text | Int

type col = { col_name : string; col_ty : col_ty }

type cell = Cell_text of string | Cell_int of int

type packed_row = Pack : 'a Caqti_type.t * 'a -> packed_row

let gen_token =
  let open Quickcheck.Generator.Let_syntax in
  let%bind len = Int.gen_incl 3 24 in
  let%map chars = List.gen_with_length len Char.gen_alphanum in
  String.of_char_list chars

let gen_tokens =
  let open Quickcheck.Generator.Let_syntax in
  let%bind n = Int.gen_incl 1 8 in
  List.gen_with_length n gen_token

(* the [ci_] prefix guarantees a valid lowercase identifier whatever the token
   starts with, and makes the names unique per position *)
let gen_cols ~min_cols ~max_cols =
  let open Quickcheck.Generator.Let_syntax in
  let%bind n = Int.gen_incl min_cols max_cols in
  let%map named =
    List.gen_with_length n
      (Quickcheck.Generator.both gen_token
         (Quickcheck.Generator.of_list [ Text; Int ]) )
  in
  List.mapi named ~f:(fun i (tok, ty) ->
      { col_name = sprintf "c%d_%s" i (String.lowercase tok); col_ty = ty } )

let gen_cell = function
  | Text ->
      Quickcheck.Generator.map gen_token ~f:(fun s -> Cell_text s)
  | Int ->
      Quickcheck.Generator.map (Int.gen_incl 0 1_000_000) ~f:(fun i ->
          Cell_int i )

let gen_row cols =
  List.map cols ~f:(fun c -> gen_cell c.col_ty) |> Quickcheck.Generator.all

let generate ~scenario ~iteration gen =
  Quickcheck.random_value
    ~seed:(`Deterministic (sprintf "%s:%d" scenario iteration))
    gen

(* helpers under test take typed params, so ints go through as ints *)
let pack_cell = function
  | Cell_text s ->
      Pack (Caqti_type.string, s)
  | Cell_int i ->
      Pack (Caqti_type.int, i)

let rec pack_row = function
  | [] ->
      failwith "pack_row: empty row"
  | [ cell ] ->
      pack_cell cell
  | cell :: rest ->
      let (Pack (t, v)) = pack_cell cell in
      let (Pack (t', v')) = pack_row rest in
      Pack (Caqti_type.t2 t t', (v, v'))

(* calls that must never collide with an earlier call's row get the iteration
   index stamped into their first cell; shapes generate the first column as
   text so there is always somewhere to stamp it *)
let stamp_first ~tag cells =
  match cells with
  | Cell_text s :: rest ->
      Cell_text (sprintf "%s-%s" tag s) :: rest
  | _ ->
      failwith "stamp_first: first generated column must be text"

let force_first_text = function
  | [] ->
      []
  | c :: rest ->
      { c with col_ty = Text } :: rest

let sql_ty = function Text -> "text" | Int -> "int"

let col_defs cols =
  List.map cols ~f:(fun c ->
      sprintf "%s %s NOT NULL" c.col_name (sql_ty c.col_ty) )
  |> String.concat ~sep:", "

let col_names cols = List.map cols ~f:(fun c -> c.col_name)

let describe_cols cols =
  List.map cols ~f:(fun c -> sprintf "%s %s" c.col_name (sql_ty c.col_ty))
  |> String.concat ~sep:", "

(* --- the helpers under test ------------------------------------------------

   The invariant under test: a helper driven N times on one connection must NOT
   register an unbounded number of server-side prepared statements — the count
   must stay bounded regardless of N (achieved by request reuse / [~oneshot]).

   Each helper is instantiated over [shapes] generated table shapes; the shape
   index is part of every seed, so different shapes also see different value
   sequences. *)

let select_insert_scenario ~shape_idx =
  let name = sprintf "select_insert_into_cols_s%d" shape_idx in
  let cols =
    generate ~scenario:"shape:select_insert_into_cols" ~iteration:shape_idx
      (gen_cols ~min_cols:2 ~max_cols:6)
    |> force_first_text
  in
  { name
  ; describe = describe_cols cols
  ; setup =
      (fun ~table ->
        sprintf "CREATE TABLE %s (id serial PRIMARY KEY, %s, UNIQUE (%s))" table
          (col_defs cols)
          (String.concat ~sep:", " (col_names cols)) )
  ; teardown = (fun ~table -> sprintf "DROP TABLE %s" table)
  ; step =
      (fun ~table conn i ->
        (* distinct key each call -> SELECT miss then INSERT: exercises BOTH
           of the requests this helper builds per call *)
        let (Pack (typ, value)) =
          generate ~scenario:name ~iteration:i (gen_row cols)
          |> stamp_first ~tag:(sprintf "k-%d" i)
          |> pack_row
        in
        Mina_caqti.select_insert_into_cols ~select:("id", Caqti_type.int)
          ~table_name:table
          ~cols:(col_names cols, typ)
          conn value
        >>| Mina_caqti.ok_exn ~ctx:name
        >>| ignore )
  }

let insert_multi_scenario ~shape_idx =
  let name = sprintf "insert_multi_into_col_s%d" shape_idx in
  (* the helper only ever writes its one column, so the generated columns are
     distractors with defaults: the table shape still varies while the call
     site stays the same *)
  let distractors =
    generate ~scenario:"shape:insert_multi_into_col" ~iteration:shape_idx
      (gen_cols ~min_cols:0 ~max_cols:4)
  in
  let distractor_defs =
    List.map distractors ~f:(fun c ->
        sprintf ", %s %s NOT NULL DEFAULT %s" c.col_name (sql_ty c.col_ty)
          (match c.col_ty with Text -> "''" | Int -> "0") )
    |> String.concat ~sep:""
  in
  { name
  ; describe =
      ( if List.is_empty distractors then "v text (no distractor columns)"
      else sprintf "v text; distractors: %s" (describe_cols distractors) )
  ; setup =
      (fun ~table ->
        sprintf
          "CREATE TABLE %s (id serial PRIMARY KEY, v text UNIQUE NOT NULL%s)"
          table distractor_defs )
  ; teardown = (fun ~table -> sprintf "DROP TABLE %s" table)
  ; step =
      (fun ~table conn i ->
        (* a varying number of values per call: the rendered VALUES list is a
           different length every time, which is the realistic shape and keeps
           the SQL text varying independently of request identity *)
        let values =
          generate ~scenario:name ~iteration:i gen_tokens
          |> List.mapi ~f:(fun j v -> sprintf "v-%d-%d-%s" i j v)
        in
        Mina_caqti.insert_multi_into_col ~table_name:table
          ~col:("v", Caqti_type.string) conn values
        >>| Mina_caqti.ok_exn ~ctx:name
        >>| ignore )
  }

let upsert_scenario ~shape_idx =
  let name = sprintf "upsert_into_cols_returning_s%d" shape_idx in
  let keys =
    generate ~scenario:"shape:upsert_keys" ~iteration:shape_idx
      (gen_cols ~min_cols:2 ~max_cols:4)
    |> force_first_text
  in
  (* payload columns share the key namespace, so offset their positions *)
  let payload =
    generate ~scenario:"shape:upsert_payload" ~iteration:shape_idx
      (gen_cols ~min_cols:1 ~max_cols:3)
    |> List.map ~f:(fun c -> { c with col_name = sprintf "p_%s" c.col_name })
  in
  let cols = keys @ payload in
  { name
  ; describe =
      sprintf "keys: %s; payload: %s" (describe_cols keys)
        (describe_cols payload)
  ; setup =
      (fun ~table ->
        sprintf "CREATE TABLE %s (id serial PRIMARY KEY, %s, UNIQUE (%s))" table
          (col_defs cols)
          (String.concat ~sep:", " (col_names keys)) )
  ; teardown = (fun ~table -> sprintf "DROP TABLE %s" table)
  ; step =
      (fun ~table conn i ->
        (* every second call reuses the previous key, so the ON CONFLICT DO
           UPDATE branch is exercised as well as the plain insert *)
        let key_index = if i % 2 = 0 then i - 1 else i in
        let key_cells =
          generate ~scenario:(name ^ ":key") ~iteration:key_index (gen_row keys)
          |> stamp_first ~tag:(sprintf "k-%d" key_index)
        in
        let payload_cells =
          generate ~scenario:(name ^ ":payload") ~iteration:i (gen_row payload)
        in
        let (Pack (typ, value)) = pack_row (key_cells @ payload_cells) in
        Mina_caqti.upsert_into_cols_returning
          ~on_conflict:(String.concat ~sep:"," (col_names keys))
          ~returning:("id", Caqti_type.int) ~table_name:table
          ~cols:(col_names cols, typ)
          conn value
        >>| Mina_caqti.ok_exn ~ctx:name
        >>| ignore )
  }

(* [insert_into_cols_returning] is the always-INSERT path: no content lookup
   and no ON CONFLICT, used for the columns whose UNIQUE constraint was dropped
   (zkapp_events / zkapp_field_array.element_ids). The generated table
   therefore carries no UNIQUE either -- adding one would let PostgreSQL
   deduplicate behind the helper and change what is being measured. *)
let insert_into_returning_scenario ~shape_idx =
  let name = sprintf "insert_into_cols_returning_s%d" shape_idx in
  let cols =
    generate ~scenario:"shape:insert_into_cols_returning" ~iteration:shape_idx
      (gen_cols ~min_cols:2 ~max_cols:6)
    |> force_first_text
  in
  { name
  ; describe = describe_cols cols
  ; setup =
      (fun ~table ->
        sprintf "CREATE TABLE %s (id serial PRIMARY KEY, %s)" table
          (col_defs cols) )
  ; teardown = (fun ~table -> sprintf "DROP TABLE %s" table)
  ; step =
      (fun ~table conn i ->
        let (Pack (typ, value)) =
          generate ~scenario:name ~iteration:i (gen_row cols)
          |> stamp_first ~tag:(sprintf "k-%d" i)
          |> pack_row
        in
        Mina_caqti.insert_into_cols_returning ~returning:("id", Caqti_type.int)
          ~table_name:table
          ~cols:(col_names cols, typ)
          conn value
        >>| Mina_caqti.ok_exn ~ctx:name
        >>| ignore )
  }

(* [insert_multi_into_col_no_dedup] renders its values into the SQL text and
   has neither ON CONFLICT nor a SELECT-back, so the column carries no UNIQUE
   constraint. Every call emits a different VALUES list, so every call is a
   distinct query string -- the last remaining sprintf-of-values path. *)
let insert_multi_no_dedup_scenario ~shape_idx =
  let name = sprintf "insert_multi_into_col_no_dedup_s%d" shape_idx in
  let distractors =
    generate ~scenario:"shape:insert_multi_into_col_no_dedup"
      ~iteration:shape_idx
      (gen_cols ~min_cols:0 ~max_cols:4)
  in
  let distractor_defs =
    List.map distractors ~f:(fun c ->
        sprintf ", %s %s NOT NULL DEFAULT %s" c.col_name (sql_ty c.col_ty)
          (match c.col_ty with Text -> "''" | Int -> "0") )
    |> String.concat ~sep:""
  in
  { name
  ; describe =
      ( if List.is_empty distractors then "v text (no distractor columns)"
      else sprintf "v text; distractors: %s" (describe_cols distractors) )
  ; setup =
      (fun ~table ->
        sprintf "CREATE TABLE %s (id serial PRIMARY KEY, v text NOT NULL%s)"
          table distractor_defs )
  ; teardown = (fun ~table -> sprintf "DROP TABLE %s" table)
  ; step =
      (fun ~table conn i ->
        let values =
          generate ~scenario:name ~iteration:i gen_tokens
          |> List.mapi ~f:(fun j v -> sprintf "v-%d-%d-%s" i j v)
        in
        Mina_caqti.insert_multi_into_col_no_dedup ~table_name:table ~col:"v"
          conn values
        >>| Mina_caqti.ok_exn ~ctx:name
        >>| ignore )
  }

let scenarios ~shapes : scenario list =
  List.concat_map
    (List.range 0 (Int.max 1 shapes))
    ~f:(fun shape_idx ->
      [ select_insert_scenario ~shape_idx
      ; insert_multi_scenario ~shape_idx
      ; upsert_scenario ~shape_idx
      ; insert_into_returning_scenario ~shape_idx
      ; insert_multi_no_dedup_scenario ~shape_idx
      ] )

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
  printf "   shape: %s\n" s.describe ;
  printf "   %-10s %-12s %-16s\n" "calls" "prepared" "plancache_KiB" ;
  let sample_and_print calls =
    let%map prepared, bytes = Sampler.sample sampler in
    printf "   %-10d %-12d %-16s\n" calls prepared
      (Option.value_map bytes ~default:"n/a" ~f:(fun b ->
           Int.to_string (b / 1024) ) ) ;
    (prepared, bytes)
  in
  let%bind prepared0, bytes0 = sample_and_print 0 in
  let%bind final_prepared, final_bytes =
    Deferred.List.fold
      (List.range 1 (iterations + 1))
      ~init:(prepared0, bytes0)
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
  let plan_cache_kib_final = Option.map final_bytes ~f:(fun b -> b / 1024) in
  (* growth against the zero-call baseline, so a session that starts with a
     warm cache does not read as a leak *)
  let plan_cache_growth =
    match (bytes0, final_bytes) with
    | Some before, Some after ->
        Some (after - before)
    | _ ->
        None
  in
  let plan_cache_growth_kib =
    Option.map plan_cache_growth ~f:(fun b -> b / 1024)
  in
  let plan_cache_bytes_per_call =
    Option.map plan_cache_growth ~f:(fun b ->
        Float.of_int b /. Float.of_int iterations )
  in
  printf
    "   RESULT scenario=%s iterations=%d prepared_final=%d \
     prepared_per_call=%.3f plan_cache_KiB_final=%s plan_cache_KiB_growth=%s \
     plan_cache_bytes_per_call=%s\n"
    s.name iterations final_prepared per_call
    (Option.value_map plan_cache_kib_final ~default:"n/a" ~f:Int.to_string)
    (Option.value_map plan_cache_growth_kib ~default:"n/a" ~f:Int.to_string)
    (Option.value_map plan_cache_bytes_per_call ~default:"n/a"
       ~f:(sprintf "%.1f") ) ;
  let%map () = C.disconnect () in
  { name = s.name
  ; prepared_final = final_prepared
  ; per_call
  ; plan_cache_kib_final
  ; plan_cache_growth_kib
  ; plan_cache_bytes_per_call
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
  (* the plan-cache fields are omitted rather than sent as 0 where the server
     has no [pg_backend_memory_contexts]: a constant-zero series charts as a
     real measurement, whereas a missing one is visibly missing. *)
  List.map results ~f:(fun r ->
      let fields =
        [ sprintf "prepared_final=%di" r.prepared_final
        ; sprintf "prepared_per_call=%.6f" r.per_call
        ; sprintf "iterations=%di" r.iterations
        ]
        @ Option.value_map r.plan_cache_kib_final ~default:[] ~f:(fun kib ->
              [ sprintf "plan_cache_kib_final=%di" kib ] )
        @ Option.value_map r.plan_cache_growth_kib ~default:[] ~f:(fun kib ->
              [ sprintf "plan_cache_growth_kib=%di" kib ] )
        @ Option.value_map r.plan_cache_bytes_per_call ~default:[]
            ~f:(fun bytes -> [ sprintf "plan_cache_bytes_per_call=%.6f" bytes ])
      in
      sprintf "%s,%s,scenario=%s %s %d" (sanitize measurement) tag_str
        (sanitize r.name)
        (String.concat ~sep:"," fields)
        ts_ns )

let main ~uri ~iterations ~sample_every ~shapes ~assert_max_prepared
    ~influxdb_file ~measurement ~tags () =
  printf "mina_caqti postgres memory-usage benchmark\n" ;
  printf "uri=%s iterations=%d sample_every=%d shapes=%d\n" (Uri.to_string uri)
    iterations sample_every shapes ;
  let%bind results =
    Deferred.List.map (scenarios ~shapes)
      ~f:(run_scenario ~uri ~iterations ~sample_every)
  in
  printf "\n== summary ==\n" ;
  List.iter results ~f:(fun r ->
      printf "   %-36s prepared_final=%-8d per_call=%-8.3f bytes_per_call=%s\n"
        r.name r.prepared_final r.per_call
        (Option.value_map r.plan_cache_bytes_per_call ~default:"n/a"
           ~f:(sprintf "%.1f") ) ) ;
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
     and shapes =
       flag "--shapes"
         (optional_with_default 2 int)
         ~doc:"S generated table shapes per helper (default 2)"
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
         ~doc:"V tag runs (e.g. baseline); else $MINA_BENCH_VARIANT"
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
           main ~uri:(Uri.of_string u) ~iterations ~sample_every ~shapes
             ~assert_max_prepared ~influxdb_file ~measurement ~tags () )
  |> Command_unix.run
