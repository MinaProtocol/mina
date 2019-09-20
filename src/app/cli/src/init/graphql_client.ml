open Core
open Async
open Signature_lib

let query_or_error
    (query_obj :
      < parse: Yojson.Basic.json -> 'response
      ; query: string
      ; variables: Yojson.Basic.json
      ; .. >) port :
    ( 'response
    , [`Failed_request of string | `Graphql_error of string] )
    Deferred.Result.t =
  let uri_string = "http://localhost:" ^ string_of_int port ^ "/graphql" in
  let variables_string = Yojson.Basic.to_string query_obj#variables in
  let body_string =
    Printf.sprintf {|{"query": "%s", "variables": %s}|} query_obj#query
      variables_string
  in
  let query_uri = Uri.of_string uri_string in
  let open Deferred.Result.Let_syntax in
  let%bind _, body =
    Deferred.Or_error.try_with ~extract_exn:true (fun () ->
        Cohttp_async.Client.post
          ~headers:
            (Cohttp.Header.add (Cohttp.Header.init ()) "Accept"
               "application/json")
          ~body:(Cohttp_async.Body.of_string body_string)
          query_uri )
    |> Deferred.Result.map_error ~f:(fun e ->
           `Failed_request (Error.to_string_hum e) )
  in
  let%bind body_str =
    Cohttp_async.Body.to_string body |> Deferred.map ~f:Result.return
  in
  let body_json = Yojson.Basic.from_string body_str in
  let open Yojson.Basic.Util in
  ( match (member "errors" body_json, member "data" body_json) with
  | `Null, `Null ->
      Error (`Graphql_error "Empty response from graphql query")
  | data, `Null ->
      Error (`Graphql_error (Yojson.Basic.to_string data))
  | _, data ->
      Result.try_with (fun () -> query_obj#parse data)
      |> Result.map_error ~f:(fun _ ->
             `Graphql_error "Encountered problem parsing graphql response" ) )
  |> Deferred.return

let query query_obj port =
  let open Deferred.Let_syntax in
  match%bind query_or_error query_obj port with
  | Ok r ->
      Deferred.return r
  | Error (`Failed_request e) ->
      eprintf
        "❌ Error connecting to daemon. You might need to start it, or \
         specify a custom --rest-port if it's already started.\n\
         Error message: %s\n\
         %!"
        e ;
      exit 17
  | Error (`Graphql_error e) ->
      eprintf "❌ Error: %s\n" e ;
      exit 17

module Encoders = struct
  let optional = Option.value_map ~default:`Null

  let uint64 value = `String (Unsigned.UInt64.to_string value)

  let amount value = `String (Currency.Amount.to_string value)

  let fee value = `String (Currency.Fee.to_string value)

  let nonce value = `String (Coda_base.Account.Nonce.to_string value)

  let uint32 value = `String (Unsigned.UInt32.to_string value)

  let public_key value = `String (Public_key.Compressed.to_base58_check value)
end

module Decoders = struct
  let optional ~f = function `Null -> None | json -> Some (f json)

  let public_key json =
    Yojson.Basic.Util.to_string json
    |> Public_key.Compressed.of_base58_check_exn

  let optional_public_key = Option.map ~f:public_key

  let uint64 json =
    Yojson.Basic.Util.to_string json |> Unsigned.UInt64.of_string

  let balance json =
    Yojson.Basic.Util.to_string json |> Currency.Balance.of_string
end
