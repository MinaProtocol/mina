(* Open-loop load: each endpoint gets requests at a fixed rate whether or not
   earlier ones have answered, so a slow server shows up as latency instead of
   as a lower request rate. [max_in_flight] bounds the requests outstanding at
   once; a request that waits for a slot still counts that wait as latency. *)

open Core
open Async

module Config = struct
  type t =
    { duration : Time.Span.t
    ; rates : (Endpoint.t * float) list  (** requests per second *)
    ; p95_limits_ms : (Endpoint.t * float) list
    ; max_in_flight : int
    ; sample_size : int
    }

  (* The bash load test's schedule (one call every 10, 10, 2, 1, 2 and 1 s).
     Well under what one rosetta serves: a search takes ~1 s of postgres time,
     and at ~20 requests/s the queue grows without bound, so latency would
     measure the queue instead of rosetta. *)
  let default_rates : (Endpoint.t * float) list =
    [ (Network_status, 0.1)
    ; (Network_options, 0.1)
    ; (Block, 0.5)
    ; (Account_balance, 1.)
    ; (Payment_transaction, 0.5)
    ; (Zkapp_transaction, 1.)
    ]

  (* About 3x the p95 of a local devnet run at [default_rates] (status 177,
     options 82, block 201, balance 123, payment search 3010, zkApp search
     3308 ms). A search by hash scans every canonical block, so it sits in
     seconds even unloaded. *)
  let default_p95_limits_ms : (Endpoint.t * float) list =
    [ (Network_status, 1000.)
    ; (Network_options, 1000.)
    ; (Block, 1000.)
    ; (Account_balance, 1000.)
    ; (Payment_transaction, 10000.)
    ; (Zkapp_transaction, 10000.)
    ]

  (* "block=2.5,account_balance=10" -> overrides on top of [defaults] *)
  let parse_overrides ~defaults s =
    String.split s ~on:','
    |> List.filter ~f:(Fn.non String.is_empty)
    |> List.fold ~init:defaults ~f:(fun acc kv ->
           match String.lsplit2 kv ~on:'=' with
           | Some (k, v) ->
               List.Assoc.add acc ~equal:Endpoint.equal (Endpoint.of_name k)
                 (Float.of_string v)
           | None ->
               failwithf "expected endpoint=value, got %s" kv () )
end

module Stats = struct
  type t =
    { mutable latencies_ms : float list
    ; mutable ok : int
    ; mutable errors : int
    ; mutable first_errors : string list  (** at most [max_kept_errors] *)
    }

  let max_kept_errors = 5

  let create () = { latencies_ms = []; ok = 0; errors = 0; first_errors = [] }

  let record t (outcome : Endpoint.outcome) =
    Option.iter outcome.latency ~f:(fun span ->
        t.latencies_ms <- Time_ns.Span.to_ms span :: t.latencies_ms ) ;
    match outcome.result with
    | Ok () ->
        t.ok <- t.ok + 1
    | Error msg ->
        t.errors <- t.errors + 1 ;
        if List.length t.first_errors < max_kept_errors then
          t.first_errors <- msg :: t.first_errors
end

(* Nearest-rank percentile, [p] in [0, 1]. *)
let percentile sorted p =
  let n = Array.length sorted in
  if n = 0 then Float.nan
  else
    let rank = Float.iround_up_exn (p *. Float.of_int n) in
    sorted.(Int.clamp_exn (rank - 1) ~min:0 ~max:(n - 1))

type summary =
  { requests : int
  ; errors : int
  ; rps : float
  ; p50 : float
  ; p95 : float
  ; p99 : float
  ; max : float
  }

let summarize (stats : Stats.t) ~elapsed_s =
  let sorted = Array.of_list stats.latencies_ms in
  Array.sort sorted ~compare:Float.compare ;
  let requests = stats.ok + stats.errors in
  { requests
  ; errors = stats.errors
  ; rps = Float.of_int requests /. elapsed_s
  ; p50 = percentile sorted 0.50
  ; p95 = percentile sorted 0.95
  ; p99 = percentile sorted 0.99
  ; max = (if Array.is_empty sorted then Float.nan else Array.last sorted)
  }

type result =
  { summaries : (Endpoint.t * summary) list
  ; memory : (string * Memory.stats) list
  ; failures : string list
  }

let run ~(config : Config.t) ~rosetta ~network ~db ~memory =
  let%bind.Deferred.Or_error samples =
    Deferred.Or_error.List.map config.rates ~f:(fun (endpoint, _) ->
        let%map.Deferred.Or_error args =
          Db.sample_for endpoint db ~limit:config.sample_size
        in
        (endpoint, Array.of_list args) )
  in
  List.iter samples ~f:(fun (endpoint, args) ->
      Proc.log "load: %d %s samples" (Array.length args)
        (Endpoint.name endpoint) ) ;
  (* An endpoint with nothing to ask about (a young devnet archive can have
     no zkApp command yet) is a test setup failure, not a pass. *)
  match List.find samples ~f:(fun (_, args) -> Array.is_empty args) with
  | Some (endpoint, _) ->
      Deferred.Or_error.errorf "load: archive has no %s to query"
        (Endpoint.name endpoint)
  | None ->
      let stats =
        List.map config.rates ~f:(fun (endpoint, _) ->
            (endpoint, Stats.create ()) )
      in
      let throttle =
        Throttle.create ~continue_on_error:true
          ~max_concurrent_jobs:config.max_in_flight
      in
      let start = Time.now () in
      let stop_at = Time.add start config.duration in
      let outstanding = ref [] in
      let fire endpoint args =
        let arg = args.(Random.int (Array.length args)) in
        let stats = List.Assoc.find_exn stats ~equal:Endpoint.equal endpoint in
        let queued_at = Time_ns.now () in
        let request =
          let%map outcome =
            Throttle.enqueue throttle (fun () ->
                Endpoint.call ~rosetta ~network endpoint ~arg )
          in
          (* latency from when the request was due, not from when a slot
             freed up *)
          let latency =
            Option.map outcome.latency ~f:(fun _ ->
                Time_ns.diff (Time_ns.now ()) queued_at )
          in
          Stats.record stats { outcome with latency }
        in
        outstanding := request :: !outstanding
      in
      let driver (endpoint, rate) =
        let args = List.Assoc.find_exn samples ~equal:Endpoint.equal endpoint in
        let interval = Time.Span.of_sec (1. /. rate) in
        let rec loop next =
          if Time.( >= ) next stop_at then return ()
          else (
            fire endpoint args ;
            let next = Time.add next interval in
            let%bind () = at next in
            loop next )
        in
        loop start
      in
      Clock.every' ~stop:(at stop_at) (Time.Span.of_sec 10.) (fun () ->
          let requests, errors =
            List.fold stats ~init:(0, 0) ~f:(fun (r, e) (_, s) ->
                (r + s.Stats.ok + s.errors, e + s.errors) )
          in
          Proc.log "load: %d requests, %d errors, %d in flight" requests errors
            (Throttle.num_jobs_running throttle) ;
          Memory.sample memory ) ;
      let%bind () = Deferred.List.iter ~how:`Parallel config.rates ~f:driver in
      (* Let the requests still out come back before scoring the run; one
         that never does counts as neither ok nor error, and shows up as a
         request count below rate * duration. *)
      let%bind () =
        Clock.with_timeout (Time.Span.of_sec 60.)
          (Deferred.all_unit !outstanding)
        >>| ignore
      in
      let elapsed_s = Time.Span.to_sec config.duration in
      let summaries =
        List.map stats ~f:(fun (endpoint, s) ->
            (endpoint, summarize s ~elapsed_s) )
      in
      let failures =
        List.concat_map summaries ~f:(fun (endpoint, summary) ->
            let s = List.Assoc.find_exn stats ~equal:Endpoint.equal endpoint in
            let errors =
              if summary.errors > 0 then
                [ sprintf "%s: %d of %d requests failed, e.g. %s"
                    (Endpoint.name endpoint) summary.errors summary.requests
                    (String.concat ~sep:" | " (List.rev s.first_errors))
                ]
              else []
            in
            let latency =
              match
                List.Assoc.find config.p95_limits_ms ~equal:Endpoint.equal
                  endpoint
              with
              | Some limit when Float.( > ) summary.p95 limit ->
                  [ sprintf "%s: p95 %.0f ms is above the %.0f ms limit"
                      (Endpoint.name endpoint) summary.p95 limit
                  ]
              | _ ->
                  []
            in
            errors @ latency )
      in
      Deferred.Or_error.return
        { summaries; memory = Memory.stats memory; failures }

let print_report result =
  printf "\n%-20s %8s %7s %7s %9s %9s %9s %9s\n" "endpoint" "requests" "errors"
    "rps" "p50 ms" "p95 ms" "p99 ms" "max ms" ;
  List.iter result.summaries ~f:(fun (endpoint, s) ->
      printf "%-20s %8d %7d %7.2f %9.1f %9.1f %9.1f %9.1f\n"
        (Endpoint.name endpoint) s.requests s.errors s.rps s.p50 s.p95 s.p99
        s.max ) ;
  printf "\n%-20s %9s %9s %9s %9s\n" "process" "max MiB" "p95 MiB" "p99 MiB"
    "median" ;
  List.iter result.memory ~f:(fun (name, (m : Memory.stats)) ->
      printf "%-20s %9.1f %9.1f %9.1f %9.1f\n" name m.max m.p95 m.p99 m.median ) ;
  printf "\n%!"

(* One InfluxDB line, sent to the bench database by
   buildkite/scripts/bench/send.sh. The memory fields keep the names the bash
   load test used, so existing dashboards still find them. *)
let influx_line result ~network ~branch ~commit =
  let escape = String.substr_replace_all ~pattern:" " ~with_:"\\ " in
  let latency_fields =
    List.concat_map result.summaries ~f:(fun (endpoint, s) ->
        let n = Endpoint.name endpoint in
        [ sprintf "%s_p50_ms=%.2f" n s.p50
        ; sprintf "%s_p95_ms=%.2f" n s.p95
        ; sprintf "%s_p99_ms=%.2f" n s.p99
        ; sprintf "%s_rps=%.2f" n s.rps
        ; sprintf "%s_errors=%di" n s.errors
        ] )
  in
  let memory_fields =
    List.concat_map result.memory ~f:(fun (name, (m : Memory.stats)) ->
        [ sprintf "%s_max=%.2f" name m.max
        ; sprintf "%s_p95=%.2f" name m.p95
        ; sprintf "%s_p99=%.2f" name m.p99
        ; sprintf "%s_median=%.2f" name m.median
        ] )
  in
  sprintf "rosetta_load_test,network=%s,branch=%s,commit=%s %s %Ld"
    (Network.to_string network)
    (escape branch) (escape commit)
    (String.concat ~sep:"," (memory_fields @ latency_fields))
    (Time_ns.to_int63_ns_since_epoch (Time_ns.now ()) |> Int63.to_int64)
