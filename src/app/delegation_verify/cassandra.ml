open Async
open Core

type 'a parser = Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or

type connection_conf = { hostname : string; port : int; use_ssl : bool }

type credentials = { username : string; password : string }

type conf =
  { executable : string
  ; connection : connection_conf option
  ; credentials : credentials option
  ; keyspace : string
  }

let make_conn_conf () : connection_conf option =
  let open Option.Let_syntax in
  let%bind hostname = Sys.getenv "CASSANDRA_HOST" in
  let%bind port = Option.map ~f:Int.of_string @@ Sys.getenv "CASSANDRA_PORT" in
  let%map use_ssl =
    Sys.getenv "CASSANDRA_USE_SSL"
    |> Option.map
         ~f:(List.mem ~equal:String.equal [ "1"; "TRUE"; "true"; "YES"; "yes" ])
  in
  { hostname; port; use_ssl }

let make_cred_conf () : credentials option =
  let open Option.Let_syntax in
  let%bind username = Sys.getenv "CASSANDRA_USERNAME" in
  let%map password = Sys.getenv "CASSANDRA_PASSWORD" in
  { username; password }

let make_conf ?executable ~keyspace : conf =
  let conn = make_conn_conf () in
  let credentials = make_cred_conf () in
  let executable =
    Option.merge executable (Sys.getenv "CQLSH") ~f:Fn.const
    |> Option.value ~default:"cqlsh"
  in
  { executable; connection = conn; credentials; keyspace }

let query ~conf q =
  let optional ~f = Option.value_map ~f ~default:[] in
  let args =
    optional conf.credentials ~f:(fun { username; password } ->
        [ "--username"; username; "--password"; password ] )
    @ optional conf.connection ~f:(fun { hostname; port; use_ssl } ->
          (if use_ssl then [ "--ssl" ] else []) @ [ hostname; Int.to_string port ] )
  in
  Process.run_lines ~prog:conf.executable ~stdin:q ~args ()

let select ~conf ~parse ~fields ?where from =
  let open Deferred.Or_error.Let_syntax in
  let%bind data =
    query ~conf
    @@ Printf.sprintf "SELECT JSON %s FROM %s.%s%s;"
         (String.concat ~sep:"," fields)
         conf.keyspace from
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

let update ~conf ~table ~where updates =
  let open Deferred.Or_error.Let_syntax in
  let assignments = List.map updates ~f:(fun (k, v) -> k ^ " = " ^ v) in
  let%map _ =
    query ~conf
    @@ Printf.sprintf "CONSISTENCY LOCAL_QUORUM; UPDATE %s.%s SET %s WHERE %s;"
         conf.keyspace table
         (String.concat ~sep:"," assignments)
         where
  in
  ()
