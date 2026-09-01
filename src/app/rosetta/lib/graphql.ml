open Core_kernel
open Async
open Rosetta_lib

let parse_response_body ~status_code body_str =
  match status_code with
  | 200 -> (
      try Ok (Yojson.Basic.from_string body_str)
      with _ ->
        Error
          (Errors.create
             ~context:"Can't parse mina daemon's GraphQL response as json"
             (`Graphql_mina_query
               (Printf.sprintf "Can't parse as json: %s" body_str) ) ) )
  | code ->
      Error
        (Errors.create ~context:"Response from Mina Daemon is not a 200"
           (`Graphql_mina_query
             (Printf.sprintf "Status code %d -- %s" code body_str) ) )

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

let query ~minimum_user_command_fee query_obj uri =
  let variables_string = Yojson.Basic.to_string query_obj#variables in
  let body_string =
    String.substr_replace_all ~pattern:"\n" ~with_:" "
    @@ Printf.sprintf {|{"query": "%s", "variables": %s}|} query_obj#query
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
    Deferred.return
    @@ parse_response_body
         ~status_code:
           (Cohttp.Code.code_of_status (Cohttp_async.Response.status response))
         body_str
  in
  let open Yojson.Basic.Util in
  ( match (member "errors" body_json, member "data" body_json) with
  | `Null, `Null ->
      Error
        (Errors.create ~context:"Empty response from Mina Daemon"
           (`Graphql_mina_query "Empty response") )
  | error, `Null ->
      Errors.Transaction_submit.of_request_error ~minimum_user_command_fee
        (graphql_error_to_string error)
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

let query_and_catch ~minimum_user_command_fee query_obj uri =
  let open Deferred.Let_syntax in
  let%map res = query ~minimum_user_command_fee query_obj uri in
  match res with Ok r -> Ok (`Successful r) | Error e -> Ok (`Failed e)

let%test_module "parse_response_body" =
  ( module struct
    let%test_unit "200 with valid JSON returns Ok" =
      match parse_response_body ~status_code:200 "{\"key\":true}" with
      | Ok _ ->
          ()
      | Error _ ->
          failwith "expected Ok"

    let%test_unit "200 with invalid JSON returns Error" =
      match parse_response_body ~status_code:200 "not valid json" with
      | Ok _ ->
          failwith "expected Error"
      | Error e ->
          let expected =
            Errors.create
              ~context:"Can't parse mina daemon's GraphQL response as json"
              (`Graphql_mina_query "Can't parse as json: not valid json")
          in
          assert (Errors.equal e expected)

    let%test_unit "non-200 returns Error with status code" =
      match parse_response_body ~status_code:500 "server error" with
      | Ok _ ->
          failwith "expected Error"
      | Error e ->
          let expected =
            Errors.create ~context:"Response from Mina Daemon is not a 200"
              (`Graphql_mina_query "Status code 500 -- server error")
          in
          assert (Errors.equal e expected)

    let%test_unit "200 with empty JSON object returns Ok" =
      match parse_response_body ~status_code:200 "{}" with
      | Ok _ ->
          ()
      | Error _ ->
          failwith "expected Ok"
  end )
