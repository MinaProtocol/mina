(* archive_memory_bench -- archive-node end-to-end memory benchmark.

   Replays the static zkApp-heavy corpus (src/test/archive/sample_zkapp_heavy)
   through the real archive insert path -- archive_blocks --precomputed ->
   Processor.add_block_aux_precomputed -> the Mina_caqti helpers -- into
   PostgreSQL, and samples the resident memory of both sides while it runs:

   - the archive_blocks process (client-side request cache);
   - the PostgreSQL backend serving it (server-side plan cache).

   A request built afresh per call leaves one more prepared statement on its
   connection, so a leak is per connection and only accumulates while that one
   connection stays open. Two things make the samples show it:

   - The Caqti pool is pinned to one connection that is never recycled
     ([pool_env]). Otherwise archive_blocks spreads the ingest over several
     backends and Caqti drops each after CAQTI_POOL_MAX_USE_COUNT uses (100 by
     default), which discards the plan cache and turns the curve into a
     sawtooth.
   - Growth is a least-squares slope against zkApp arrays inserted, not against
     time. The corpus is a chain whose zkApp-heavy blocks arrive near its end;
     against time, "heavy blocks started" is indistinguishable from a leak.

   No threshold is applied: this measures, it does not gate. The result is one
   InfluxDB line-protocol point for buildkite/scripts/bench/send.sh, with the
   fields the Python version published. The backend RSS is read from /proc,
   which works because RunWithPostgres runs PostgreSQL with --pid=host. *)

open Core
open Async

(* Caqti reads these in connect_pool (Caqti_pool_config.default_from_env), and
   they win over its ?max_size argument: one connection, kept between uses,
   never closed for idleness, never recycled after N uses. *)
let pool_env =
  [ ("CAQTI_POOL_MAX_SIZE", "1")
  ; ("CAQTI_POOL_MAX_IDLE_SIZE", "1")
  ; ("CAQTI_POOL_MAX_IDLE_AGE", "none")
  ; ("CAQTI_POOL_MAX_USE_COUNT", "none")
  ]

let log_tail_lines = 60

let ok_exn ~ctx = function
  | Ok x ->
      x
  | Error e ->
      failwithf "%s: %s" ctx (Caqti_error.show e) ()

let int_opt s = Option.try_with (fun () -> Int.of_string s)

(* VmRSS of a process in KiB, or 0 if it is gone *)
let vm_rss_kib pid =
  match In_channel.read_lines (sprintf "/proc/%d/status" pid) with
  | lines ->
      List.find_map lines ~f:(fun line ->
          match
            String.split_on_chars line ~on:[ ' '; '\t' ]
            |> List.filter ~f:(Fn.non String.is_empty)
          with
          | "VmRSS:" :: kib :: _ ->
              int_opt kib
          | _ ->
              None )
      |> Option.value ~default:0
  | exception _ ->
      0

module Sample = struct
  type t =
    { elapsed : float
    ; blocks : int
    ; arrays : int
    ; archive_rss : int
    ; backend_rss : int
    ; pids : int list
    }

  let header =
    "elapsed_s,blocks_done,zkapp_arrays,ab_rss_kib,pg_rss_kib,pg_backends"

  let row t =
    sprintf "%.1f,%d,%d,%d,%d,%d" t.elapsed t.blocks t.arrays t.archive_rss
      t.backend_rss (List.length t.pids)
end

(* The sampler's queries, on a connection of its own. Its backend is excluded
   by pid, so what remains in the database is the ingest. The zkApp array
   count is rows in the two variable-width array tables: those inserts drive
   the leaking helpers, unlike the plain blocks around them. *)
module Db = struct
  let progress_req =
    Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.(t3 int int string))
      ~oneshot:true
      "SELECT (SELECT count(*)::int FROM blocks), ((SELECT count(*) FROM \
       zkapp_field_array) + (SELECT count(*) FROM zkapp_events))::int, \
       coalesce(string_agg(pid::text, ' '), '') FROM pg_stat_activity WHERE \
       datname = current_database() AND backend_type = 'client backend' AND \
       pid <> pg_backend_pid()"

  let progress (module Conn : Mina_caqti.CONNECTION) =
    let%map blocks, arrays, pids =
      Conn.find progress_req () >>| ok_exn ~ctx:"sample"
    in
    let pids = String.split pids ~on:' ' |> List.filter_map ~f:int_opt in
    (blocks, arrays, pids)

  let scalar (module Conn : Mina_caqti.CONNECTION) typ sql =
    Conn.find
      Caqti_request.Infix.((Caqti_type.unit ->! typ) ~oneshot:true sql)
      ()
    >>| ok_exn ~ctx:sql
end

(* archive_blocks keeps --successful-files / --failed-files to itself until it
   exits, so these are the final verdict, not live progress *)
let count_lines path =
  match In_channel.read_lines path with
  | lines ->
      List.length lines
  | exception _ ->
      0

let print_log_tail log =
  match In_channel.read_lines log with
  | lines ->
      let tail = List.drop lines (List.length lines - log_tail_lines) in
      printf "=== last %d lines of %s ===\n" (List.length tail) log ;
      List.iter tail ~f:print_endline
  | exception e ->
      printf "could not read %s: %s\n" log (Exn.to_string e)

let rec json_files dir =
  Sys_unix.ls_dir dir
  |> List.concat_map ~f:(fun name ->
         let path = dir ^/ name in
         if Sys_unix.is_directory_exn path then json_files path
         else if String.is_suffix name ~suffix:".json" then [ path ]
         else [] )

let unpack_corpus ~corpus ~workdir ~limit =
  let%map () =
    Process.run_expect_no_output_exn ~prog:"tar"
      ~args:[ "-xJf"; corpus; "-C"; workdir ]
      ()
  in
  let blocks = json_files workdir |> List.sort ~compare:String.compare in
  if limit > 0 then List.take blocks limit else blocks

let rec sample_until_exit ~process ~sampler ~started ~interval ~base acc =
  let pid = Pid.to_int (Process.pid process) in
  let archive_rss = vm_rss_kib pid in
  let%bind blocks, arrays, pids = Db.progress sampler in
  let blocks_before, arrays_before = base in
  let sample =
    { Sample.elapsed =
        Time_ns.Span.to_sec (Time_ns.diff (Time_ns.now ()) started)
    ; blocks = blocks - blocks_before
    ; arrays = arrays - arrays_before
    ; archive_rss
    ; backend_rss = List.sum (module Int) pids ~f:vm_rss_kib
    ; pids
    }
  in
  let acc = sample :: acc in
  match%bind Clock_ns.with_timeout interval (Process.wait process) with
  | `Result status ->
      return (List.rev acc, status)
  | `Timeout ->
      sample_until_exit ~process ~sampler ~started ~interval ~base acc

(* Ingestion starts at the first sample that reports a block written; the
   samples before it are process start-up, whose ramp would read as growth.
   Taken from the curve itself rather than a fixed RSS threshold, so the
   baseline stays right whatever the binary's footprint becomes. *)
let steady_samples curve =
  match List.drop_while curve ~f:(fun (s : Sample.t) -> s.blocks <= 0) with
  | [] ->
      List.filter curve ~f:(fun s -> s.archive_rss > 0)
  | steady ->
      steady

(* (slope, r^2) of a least-squares line; (0, 0) when x does not vary *)
let linear_fit points =
  let n = Float.of_int (List.length points) in
  if Float.(n < 2.) then (0., 0.)
  else
    let mean f = List.sum (module Float) points ~f /. n in
    let mean_x = mean fst and mean_y = mean snd in
    let sum f = List.sum (module Float) points ~f in
    let var_x = sum (fun (x, _) -> (x -. mean_x) ** 2.) in
    if Float.(var_x = 0.) then (0., 0.)
    else
      let cov = sum (fun (x, y) -> (x -. mean_x) *. (y -. mean_y)) in
      let var_y = sum (fun (_, y) -> (y -. mean_y) ** 2.) in
      let r2 =
        if Float.(var_y > 0.) then cov *. cov /. (var_x *. var_y) else 0.
      in
      (cov /. var_x, r2)

(* KiB per 1000 zkApp arrays, fitted only where arrays are being inserted:
   before the first one there is no leaking work to attribute memory to *)
let growth_slope samples value =
  let slope, r2 =
    List.filter_map samples ~f:(fun (s : Sample.t) ->
        let v = value s in
        if s.arrays > 0 && v > 0 then
          Some (Float.of_int s.arrays, Float.of_int v)
        else None )
    |> linear_fit
  in
  (slope *. 1000., r2)

type metrics =
  { archive_growth : int
  ; archive_slope : float
  ; backend_peak : int
  ; backend_tail_average : int
  ; backend_slope : float
  ; backend_slope_r2 : float
  ; arrays : int
  ; pid_changes : int
  ; max_backends : int
  }

let compute_metrics curve =
  match steady_samples curve with
  | [] ->
      { archive_growth = 0
      ; archive_slope = 0.
      ; backend_peak = 0
      ; backend_tail_average = 0
      ; backend_slope = 0.
      ; backend_slope_r2 = 0.
      ; arrays = 0
      ; pid_changes = 0
      ; max_backends = 0
      }
  | first :: _ as steady ->
      let last = List.last_exn steady in
      let archive_slope, _ = growth_slope steady (fun s -> s.archive_rss) in
      let backend_slope, backend_slope_r2 =
        growth_slope steady (fun s -> s.backend_rss)
      in
      let backend =
        List.filter_map steady ~f:(fun s ->
            Option.some_if (s.backend_rss > 0) s.backend_rss )
      in
      let tail = List.drop backend (2 * List.length backend / 3) in
      (* a pinned pool keeps one backend for the whole ingest; any change of
         pid means the plan cache was thrown away and growth is understated *)
      let seen =
        List.filter_map steady ~f:(fun s ->
            Option.some_if (not (List.is_empty s.pids)) s.pids )
      in
      let pid_changes =
        List.zip_exn (List.drop_last_exn (List.hd_exn seen :: seen)) seen
        |> List.count ~f:(fun (a, b) -> not (List.equal Int.equal a b))
      in
      { archive_growth = last.archive_rss - first.archive_rss
      ; archive_slope
      ; backend_peak =
          List.max_elt backend ~compare:Int.compare |> Option.value ~default:0
      ; backend_tail_average =
          ( if List.is_empty tail then 0
          else List.sum (module Int) tail ~f:Fn.id / List.length tail )
      ; backend_slope
      ; backend_slope_r2
      ; arrays = last.arrays
      ; pid_changes
      ; max_backends =
          List.map seen ~f:List.length
          |> List.max_elt ~compare:Int.compare
          |> Option.value ~default:0
      }

let sanitize = String.map ~f:(function ' ' | ',' | '=' -> '_' | c -> c)

let main ~uri ~archive_blocks ~corpus ~limit ~interval ~max_failed ~perf_file
    ~measurement ~tags () =
  let%bind sampler = Mina_caqti.connect uri >>| ok_exn ~ctx:"connect" in
  let%bind database =
    Db.scalar sampler Caqti_type.string "SELECT current_database()"
  in
  let%bind version =
    Db.scalar sampler Caqti_type.string "SHOW server_version_num"
    >>| Int.of_string
  in
  printf "Benchmarking against database '%s' (server_version_num=%d)\n" database
    version ;
  let%bind has_schema =
    Db.scalar sampler Caqti_type.bool
      "SELECT to_regclass('public.blocks') IS NOT NULL"
  in
  if not has_schema then
    failwithf
      "database '%s' carries no archive schema; load \
       src/app/archive/create_schema.sql into it first"
      database () ;
  printf "Pinning the Caqti pool to one never-recycled connection: %s\n"
    (List.map pool_env ~f:(fun (k, v) -> k ^ "=" ^ v) |> String.concat ~sep:" ") ;
  let workdir = Filename_unix.temp_dir "archive_memory_bench" "" in
  let%bind blocks = unpack_corpus ~corpus ~workdir ~limit in
  printf "Feeding %d precomputed blocks and sampling memory...\n%!"
    (List.length blocks) ;
  let successful = workdir ^/ "successful" and failed = workdir ^/ "failed" in
  let log = workdir ^/ "archive_blocks.log" in
  (* progress is read from the database, so start from what it already holds *)
  let%bind blocks_before, arrays_before, _ = Db.progress sampler in
  let%bind process =
    Process.create_exn ~prog:"bash"
      ~args:
        ( [ "-c"
          ; "exec \"$0\" \"$@\" > " ^ Filename.quote log ^ " 2>&1"
          ; archive_blocks
          ; "--archive-uri"
          ; Uri.to_string uri
          ; "--precomputed"
          ; "--successful-files"
          ; successful
          ; "--failed-files"
          ; failed
          ; "--log-successful"
          ; "false"
          ]
        @ blocks )
      ~env:(`Extend pool_env) ()
  in
  let started = Time_ns.now () in
  let%bind curve, status =
    sample_until_exit ~process ~sampler ~started ~interval
      ~base:(blocks_before, arrays_before)
      []
  in
  let ingest_seconds =
    Time_ns.Span.to_sec (Time_ns.diff (Time_ns.now ()) started)
  in
  ( match status with
  | Ok () ->
      ()
  | Error e ->
      print_log_tail log ;
      failwithf "archive_blocks failed: %s"
        (Core_unix.Exit_or_signal.to_string_hum (Error e))
        () ) ;
  (* archive_blocks exits 0 even when every block fails; a run that measured
     nothing must not reach the dashboards as a leak-free build *)
  let blocks_ok = count_lines successful in
  let blocks_failed = count_lines failed in
  if blocks_failed > 0 then print_log_tail log ;
  if blocks_ok = 0 then
    failwithf
      "no block was ingested (%d failed); refusing to publish a zero \
       measurement"
      blocks_failed () ;
  if blocks_failed > max_failed then
    failwithf "%d blocks failed to insert, more than the %d allowed"
      blocks_failed max_failed () ;
  let m = compute_metrics curve in
  let blocks_per_sec =
    if Float.(ingest_seconds > 0.) then Float.of_int blocks_ok /. ingest_seconds
    else 0.
  in
  let fields =
    [ sprintf "blocks_ok=%di" blocks_ok
    ; sprintf "blocks_failed=%di" blocks_failed
    ; sprintf "zkapp_arrays=%di" m.arrays
    ; sprintf "archive_rss_growth_kib=%di" m.archive_growth
    ; sprintf "archive_rss_kib_per_1k_arrays=%.3f" m.archive_slope
    ; sprintf "pg_backend_rss_peak_kib=%di" m.backend_peak
    ; sprintf "pg_backend_rss_tail_avg_kib=%di" m.backend_tail_average
    ; sprintf "pg_backend_rss_kib_per_1k_arrays=%.3f" m.backend_slope
    ; sprintf "pg_backend_rss_slope_r2=%.3f" m.backend_slope_r2
    ; sprintf "pg_backend_changes=%di" m.pid_changes
    ; sprintf "pg_backends_max=%di" m.max_backends
    ; sprintf "ingest_seconds=%di" (Float.iround_down_exn ingest_seconds)
    ; sprintf "blocks_per_sec=%.3f" blocks_per_sec
    ]
  in
  let line =
    sprintf "%s,%s %s %d" (sanitize measurement)
      ( List.map tags ~f:(fun (k, v) -> sprintf "%s=%s" k (sanitize v))
      |> String.concat ~sep:"," )
      (String.concat ~sep:"," fields)
      (Time_ns.to_int_ns_since_epoch (Time_ns.now ()))
  in
  Option.iter perf_file ~f:(fun path -> Out_channel.write_lines path [ line ]) ;
  printf "=== growth curve ===\n%s\n" Sample.header ;
  List.iter curve ~f:(fun s -> print_endline (Sample.row s)) ;
  printf "=== summary ===\n" ;
  printf "  blocks_ok=%d blocks_failed=%d\n" blocks_ok blocks_failed ;
  printf "  zkApp arrays inserted       : %d\n" m.arrays ;
  printf "  archive_blocks RSS growth   : %d KiB\n" m.archive_growth ;
  printf "  archive_blocks RSS slope    : %.3f KiB / 1000 arrays\n"
    m.archive_slope ;
  printf "  pg backend RSS peak         : %d KiB (%d MiB)\n" m.backend_peak
    (m.backend_peak / 1024) ;
  printf "  pg backend RSS tail average : %d KiB (%d MiB)\n"
    m.backend_tail_average
    (m.backend_tail_average / 1024) ;
  printf "  pg backend RSS slope        : %.3f KiB / 1000 arrays (r2=%.3f)\n"
    m.backend_slope m.backend_slope_r2 ;
  printf "  pg backends                 : at most %d, changed %d times\n"
    m.max_backends m.pid_changes ;
  if m.max_backends > 1 || m.pid_changes > 0 then
    printf
      "  note: the ingest did not run on one stable backend, so the growth \
       numbers understate the leak\n" ;
  printf "  ingest time                 : %.0f s\n" ingest_seconds ;
  printf "  throughput                  : %.3f blocks/s\n" blocks_per_sec ;
  printf "=== influxdb line protocol ===\n%s\n" line ;
  let (module Conn : Mina_caqti.CONNECTION) = sampler in
  Conn.disconnect ()

let () =
  Command.async
    ~summary:
      "Archive-node end-to-end memory benchmark over a zkApp-heavy corpus"
    (let%map_open.Command uri =
       flag "--uri" (required string)
         ~doc:"URI archive database with create_schema.sql loaded"
     and archive_blocks =
       flag "--archive-blocks"
         (optional_with_default
            "_build/default/src/app/archive_blocks/archive_blocks.exe" string )
         ~doc:"PATH archive_blocks executable"
     and corpus =
       flag "--corpus"
         (optional_with_default
            "src/test/archive/sample_zkapp_heavy/precomputed_blocks.tar.xz"
            string )
         ~doc:"PATH corpus archive (.tar.xz of precomputed blocks)"
     and limit =
       flag "--limit"
         (optional_with_default 0 int)
         ~doc:"N replay only the first N blocks (default: all)"
     and interval =
       flag "--sample-interval"
         (optional_with_default 0.1 float)
         ~doc:"SEC sampling period (default 0.1)"
     and max_failed =
       flag "--max-failed-blocks"
         (optional_with_default 0 int)
         ~doc:"N blocks allowed to fail before the run is refused (default 0)"
     and perf_file =
       flag "--influxdb-file" (optional string)
         ~doc:"PATH write the InfluxDB line-protocol point here"
     and measurement =
       flag "--measurement"
         (optional_with_default "archive_memory_bench" string)
         ~doc:"NAME InfluxDB measurement"
     and branch = flag "--git-branch" (optional string) ~doc:"B branch tag"
     and commit = flag "--git-commit" (optional string) ~doc:"C commit tag"
     and variant = flag "--variant" (optional string) ~doc:"V variant tag" in
     fun () ->
       let tag k v = (k, Option.value v ~default:"unknown") in
       main ~uri:(Uri.of_string uri) ~archive_blocks ~corpus ~limit
         ~interval:(Time_ns.Span.of_sec interval)
         ~max_failed ~perf_file ~measurement
         ~tags:
           [ tag "variant" variant
           ; tag "git_branch" branch
           ; tag "git_commit" commit
           ]
         () )
  |> Command_unix.run
