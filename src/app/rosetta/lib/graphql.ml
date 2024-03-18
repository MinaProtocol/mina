open Core_kernel
open Async
open Rosetta_lib

let graphql_error_to_string e =
  let error_obj_to_string obj =
    let open Yojson.Basic in
    let obj_message =
      let open Option.Let_syntax in
      let%bind message = Util.to_option (Util.member "message") obj in
      let%map path = Util.to_option (Util.member "path") obj in
      let message =
        Util.to_string_option message
        |> Option.value ~default:(Yojson.Basic.to_string message)
      in
      Printf.sprintf "%s (in %s)" message (Yojson.Basic.to_string path)
    in
    match obj_message with Some m -> m | None -> to_string obj
  in
  match e with
  | `List l ->
      List.map ~f:error_obj_to_string l |> String.concat ~sep:"\n"
  | e ->
      error_obj_to_string e

let query query_obj uri =
  let variables_string = Yojson.Basic.to_string query_obj#variables in
  let body_string =
    Printf.sprintf {|{"query": "%s", "variables": %s}|} query_obj#query
      variables_string
  in
  let open Deferred.Result.Let_syntax in
  let headers =
    Cohttp.Header.of_list
      [ ("Content-Type", "application/json"); ("Accept", "application/json") ]
  in
  let%bind response, body =
    Deferred.Or_error.try_with ~here:[%here] ~extract_exn:true (fun () ->
        Cohttp_async.Client.post ~headers
          ~body:(Cohttp_async.Body.of_string body_string)
          uri )
    |> Deferred.Result.map_error ~f:(fun e ->
           Errors.create ~context:"Internal POST to Mina Daemon failed"
             (`Graphql_mina_query (Error.to_string_hum e)) )
  in
  let%bind body_str =
    Cohttp_async.Body.to_string body |> Deferred.map ~f:Result.return
  in
  let%bind body_json =
    match
      Cohttp.Code.code_of_status (Cohttp_async.Response.status response)
    with
    | 200 ->
        Deferred.return (Ok (Yojson.Basic.from_string body_str))
    | code ->
        Deferred.return
          (Error
             (Errors.create ~context:"Response from Mina Daemon is not a 200"
                (`Graphql_mina_query
                  (Printf.sprintf "Status code %d -- %s" code body_str) ) ) )
  in
  let open Yojson.Basic.Util in
  ( match (member "errors" body_json, member "data" body_json) with
  | `Null, `Null ->
      Error
        (Errors.create ~context:"Empty response from Mina Daemon"
           (`Graphql_mina_query "Empty response") )
  | error, `Null ->
      Errors.Transaction_submit.of_request_error (graphql_error_to_string error)
      |> Option.value
           ~default:
             (Errors.create ~context:"Explicit error response from Mina Daemon"
                (`Graphql_mina_query (graphql_error_to_string error)) )
      |> Result.fail
  | _, raw_json ->
      Result.try_with (fun () -> query_obj#parse raw_json)
      |> Result.map_error ~f:(fun e ->
             Errors.create
               ~context:"JSON parse error in response from Mina Daemon"
               (`Graphql_mina_query
                 (Printf.sprintf "Error parsing graphql response: %s"
                    (Exn.to_string e) ) ) ) )
  |> Deferred.return

let query_and_catch query_obj uri =
  let open Deferred.Let_syntax in
  let%map res = query query_obj uri in
  match res with Ok r -> Ok (`Successful r) | Error e -> Ok (`Failed e)
