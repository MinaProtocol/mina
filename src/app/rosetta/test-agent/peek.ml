(** Observing the state of the network through the lens of Rosetta *)

open Async
open Core_kernel
open Models
open Lib

module Lift = struct
  let json res =
    res
    |> Result.map_error ~f:(fun str -> Errors.create (`Json_parse (Some str)))
    |> Deferred.return

  let res res ~of_yojson =
    Result.bind res ~f:(fun r ->
        of_yojson r
        |> Result.map_error ~f:(fun str ->
               Errors.create (`Json_parse (Some str)) ) )

  let must_succeed rr = failwith "TODO"

  let req req =
    let open Deferred.Let_syntax in
    let%bind response, body = req in
    let%bind str = Cohttp_async.Body.to_string body in
    match Cohttp_async.Response.status response with
    | `OK -> (
      match Yojson.Safe.from_string str with
      | body ->
          Deferred.Result.return (Ok body)
      | exception Yojson.Json_error err ->
          Deferred.Result.fail
            (Errors.create ~context:"Parsing rosetta body"
               (`Json_parse (Some err))) )
    | _ -> (
      match Yojson.Safe.from_string str with
      | body ->
          Errors.of_yojson body |> json
          |> Deferred.Result.map ~f:(fun e -> Error e)
      | exception Yojson.Json_error err ->
          Deferred.Result.fail
            (Errors.create ~context:"Parsing Rosetta error"
               (`Json_parse (Some err))) )
end

let post ~rosetta_uri ~body ~path =
  Cohttp_async.Client.post
    ~headers:
      Cohttp.Header.(init () |> fun t -> add t "Accept" "application/json")
    ~body:(body |> Yojson.Safe.to_string |> Cohttp_async.Body.of_string)
    (Uri.with_path rosetta_uri path)
  |> Lift.req

module Network = struct
  open Deferred.Result.Let_syntax

  let list ~rosetta_uri =
    let%map res =
      post ~rosetta_uri
        ~body:Metadata_request.(create () |> to_yojson)
        ~path:"network/list"
    in
    Lift.res res ~of_yojson:Network_list_response.of_yojson
    |> Lift.must_succeed

  let status ~rosetta_uri ~network_response =
    let%map res =
      post ~rosetta_uri
        ~body:
          Network_request.(
            create
              (List.hd_exn
                 network_response.Network_list_response.network_identifiers)
            |> to_yojson)
        ~path:"network/status"
    in
    Lift.res res ~of_yojson:Network_status_response.of_yojson
end

module Mempool = struct
  open Deferred.Result.Let_syntax

  let mempool ~rosetta_uri ~network_response =
    let%map res =
      post ~rosetta_uri
        ~body:
          Network_request.(
            create
              (List.hd_exn
                 network_response.Network_list_response.network_identifiers)
            |> to_yojson)
        ~path:"mempool/"
    in
    Lift.res res ~of_yojson:Mempool_response.of_yojson
end
