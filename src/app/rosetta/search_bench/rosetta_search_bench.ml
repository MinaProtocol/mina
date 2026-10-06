(* rosetta_search_bench -- latency of POST /search/transactions.

   Runs the endpoint's SQL path ([Search.Sql.run], what the handler calls once
   it has a connection) against an archive loaded with init.sql, for the
   filter shapes clients send, and reports per shape the median/min/max over
   [--runs] timed runs after one warm-up. [Search.Sql.User_commands.run] is
   timed separately, as it is the part an account filter is slow in.

   Results go to stdout and, with [--influxdb-file], to InfluxDB line protocol
   for buildkite/scripts/bench/send.sh, using the same tags as the pg_memory
   bench. *)

open Core
open Async
module Search = Lib.Search
module Query = Search.Transaction_query

(* Ids and fixtures as laid out by generate.sql. *)
module Fixture = struct
  let busy_account = 1

  let medium_account = 2

  (* the first command paid by [medium_account] *)
  let medium_command = 5001

  (* paid by [busy_account] *)
  let busy_command = 100

  let default_token = Mina_base.Token_id.(to_string default)
end

let ok_exn ~ctx = function
  | Ok x ->
      x
  | Error e ->
      failwithf "%s: %s" ctx (Caqti_error.show e) ()

let lookup (module Conn : Mina_caqti.CONNECTION) sql id =
  Conn.find (Mina_caqti.find_req Caqti_type.int Caqti_type.string sql) id
  >>| ok_exn ~ctx:sql

let public_key conn id =
  lookup conn "SELECT value FROM public_keys WHERE id = ?" id

let command_hash conn id =
  lookup conn "SELECT hash FROM user_commands WHERE id = ?" id

type shape = { name : string; query : Query.t }

let shapes (module Conn : Mina_caqti.CONNECTION) =
  let conn = (module Conn : Mina_caqti.CONNECTION) in
  let%bind busy = public_key conn Fixture.busy_account in
  let%bind medium = public_key conn Fixture.medium_account in
  let%bind sparse =
    Conn.find
      (Mina_caqti.find_req Caqti_type.unit Caqti_type.string
         "SELECT value FROM public_keys ORDER BY id DESC LIMIT 1" )
      ()
    >>| ok_exn ~ctx:"sparse account"
  in
  let%bind medium_hash = command_hash conn Fixture.medium_command in
  let%map busy_hash = command_hash conn Fixture.busy_command in
  let account address =
    { Query.Filter.address; token_id = Fixture.default_token }
  in
  let page = Some 100L in
  let q ?operator ?limit filter = Query.make ?operator ?limit ~filter () in
  [ { name = "account_busy"
    ; query =
        q ?limit:page (Query.Filter.make ~account_identifier:(account busy) ())
    }
  ; { name = "account_medium"
    ; query =
        q ?limit:page
          (Query.Filter.make ~account_identifier:(account medium) ())
    }
  ; { name = "account_sparse_receiver"
    ; query =
        q ?limit:page
          (Query.Filter.make ~account_identifier:(account sparse) ())
    }
  ; { name = "address_medium"
    ; query = q ?limit:page (Query.Filter.make ~address:medium ())
    }
  ; { name = "hash_only"
    ; query = q (Query.Filter.make ~transaction_hash:busy_hash ())
    }
  ; { name = "status_failed"
    ; query = q ?limit:page (Query.Filter.make ~op_status:"failed" ())
    }
  ; { name = "account_and_hash"
    ; query =
        q
          (Query.Filter.make ~account_identifier:(account medium)
             ~transaction_hash:medium_hash () )
    }
  ; { name = "address_or_hash"
    ; query =
        q ~operator:`Or ?limit:page
          (Query.Filter.make ~address:medium ~transaction_hash:busy_hash ())
    }
  ]

type result =
  { shape : string
  ; scope : string
  ; total_count : int64
  ; median_ms : float
  ; min_ms : float
  ; max_ms : float
  ; runs : int
  }

let time f =
  let started = Time_ns.now () in
  let%map count = f () in
  (count, Time_ns.Span.to_ms (Time_ns.diff (Time_ns.now ()) started))

let median xs =
  let xs = List.sort xs ~compare:Float.compare |> Array.of_list in
  let n = Array.length xs in
  if n % 2 = 1 then xs.(n / 2) else (xs.((n / 2) - 1) +. xs.(n / 2)) /. 2.

(* one warm-up, then [runs] timed calls; [f] returns the total count *)
let measure ~runs ~shape ~scope f =
  let%bind _ = f () in
  let%map samples =
    Deferred.List.init ~how:`Sequential runs ~f:(fun _ -> time f)
  in
  let times = List.map samples ~f:snd in
  let total_count = fst (List.hd_exn samples) in
  { shape
  ; scope
  ; total_count
  ; median_ms = median times
  ; min_ms = List.reduce_exn times ~f:Float.min
  ; max_ms = List.reduce_exn times ~f:Float.max
  ; runs
  }

let endpoint conn ~logger (query : Query.t) () =
  Search.Sql.run conn ~logger query
  >>| function
  | Ok { Search.Transactions_info.total_count; _ } ->
      total_count
  | Error e ->
      failwithf "search: %s"
        (Yojson.Safe.to_string (Rosetta_lib.Errors.to_yojson e))
        ()

let user_commands conn ~logger (query : Query.t) () =
  Search.Sql.User_commands.run conn ~logger ~offset:query.offset
    ~limit:query.limit query
  >>| ok_exn ~ctx:"user commands"
  >>| fst

(* line-protocol tag values must not contain unescaped spaces/commas/= *)
let sanitize = String.map ~f:(function ' ' | ',' | '=' -> '_' | c -> c)

let influx_lines ~measurement ~tags results =
  let ts = Time_ns.now () |> Time_ns.to_int_ns_since_epoch in
  let tags =
    List.map tags ~f:(fun (k, v) -> sprintf "%s=%s" k (sanitize v))
    |> String.concat ~sep:","
  in
  List.map results ~f:(fun r ->
      sprintf
        "%s,%s,shape=%s,scope=%s \
         median_ms=%.3f,min_ms=%.3f,max_ms=%.3f,total_count=%Ldi,runs=%di %d"
        measurement tags r.shape r.scope r.median_ms r.min_ms r.max_ms
        r.total_count r.runs ts )

let main ~uri ~runs ~influxdb_file ~measurement ~tags () =
  let logger = Logger.null () in
  let%bind conn = Mina_caqti.connect uri >>| ok_exn ~ctx:"connect" in
  let%bind shapes = shapes conn in
  printf "rosetta /search/transactions bench: %d runs per shape\n" runs ;
  printf "%-26s %-14s %12s %10s %10s %10s\n" "shape" "scope" "total_count"
    "median_ms" "min_ms" "max_ms" ;
  let%bind results =
    Deferred.List.concat_map ~how:`Sequential shapes ~f:(fun { name; query } ->
        Deferred.List.map ~how:`Sequential
          [ ("endpoint", endpoint conn ~logger query)
          ; ("user_commands", user_commands conn ~logger query)
          ]
          ~f:(fun (scope, f) ->
            let%map r = measure ~runs ~shape:name ~scope f in
            printf "%-26s %-14s %12Ld %10.1f %10.1f %10.1f\n%!" r.shape r.scope
              r.total_count r.median_ms r.min_ms r.max_ms ;
            r ) )
  in
  Option.iter influxdb_file ~f:(fun path ->
      Out_channel.write_lines path (influx_lines ~measurement ~tags results) ;
      printf "wrote %d points to %s\n" (List.length results) path ) ;
  let (module Conn : Mina_caqti.CONNECTION) = conn in
  Conn.disconnect ()

let () =
  Command.async
    ~summary:"Time Rosetta /search/transactions against a synthetic archive"
    (let%map_open.Command uri =
       flag "--uri" (required string)
         ~doc:"URI archive database loaded with search_bench/init.sql"
     and runs =
       flag "--runs"
         (optional_with_default 5 int)
         ~doc:"N timed runs per shape, after one warm-up (default 5)"
     and influxdb_file =
       flag "--influxdb-file" (optional string)
         ~doc:"PATH write InfluxDB line protocol here"
     and measurement =
       flag "--measurement"
         (optional_with_default "rosetta_search_bench" string)
         ~doc:"NAME InfluxDB measurement"
     and branch = flag "--git-branch" (optional string) ~doc:"B branch tag"
     and commit = flag "--git-commit" (optional string) ~doc:"C commit tag"
     and variant = flag "--variant" (optional string) ~doc:"V variant tag" in
     fun () ->
       let tag k v = (k, Option.value v ~default:"unknown") in
       main ~uri:(Uri.of_string uri) ~runs:(Int.max 1 runs) ~influxdb_file
         ~measurement
         ~tags:
           [ tag "branch" branch; tag "commit" commit; tag "variant" variant ]
         () )
  |> Command_unix.run
