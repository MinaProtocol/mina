open Async
open Core

type 'a parser = Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or

let query ?executable q =
  let prog =
    Option.merge executable (Sys.getenv "CQLSH") ~f:Fn.const
    |> Option.value ~default:"cqlsh"
  in
  printf "SQL: '%s'\n" q ;
  Process.run_lines ~prog ~stdin:q ~args:[] ()

let select ?executable ~keyspace ~parse ~fields ?where from =
  let open Deferred.Or_error.Let_syntax in
  let%bind data = 
    query ?executable
    @@ Printf.sprintf "SELECT JSON %s FROM %s.%s%s;"
         (String.concat ~sep:"," fields)
         keyspace from
         (match where with None -> "" | Some w -> " WHERE " ^ w)
  in
  List.slice data 3 (-2) (* skip header and footer *)
  |> List.filter ~f:(fun s -> not (String.is_empty s))
  |> List.fold_right ~init:(Ok []) ~f:(fun line acc ->
         let open Or_error.Let_syntax in
         let%bind l = acc in
         try
           let j = Yojson.Safe.from_string line in
           match parse j with
           | Ppx_deriving_yojson_runtime.Result.Ok s ->
               Ok (s :: l)
           | Ppx_deriving_yojson_runtime.Result.Error e ->
               Or_error.error_string e
         with Yojson.Json_error e -> Or_error.error_string e )
  |> Deferred.return

let update ?executable ~keyspace ~table ~where updates =
  let open Deferred.Or_error.Let_syntax in
  let assignments = List.map updates ~f:(fun (k, v) -> k ^ " = " ^ v) in
  let%map _ = 
    query ?executable
    @@ Printf.sprintf "UPDATE %s.%s SET %s WHERE %s;"
         keyspace table
         (String.concat ~sep:"," assignments)
         where
  in
  ()
