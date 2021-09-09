(** Observing the state of the network through the lens of Rosetta *)

open Async
open Core_kernel
open Rosetta_models
open Rosetta_lib

module Lift = struct
  let json res =
    res
    |> Result.map_error ~f:(fun str -> Errors.create (`Json_parse (Some str)))

  let res res ~logger:_ ~of_yojson =
    Result.bind res ~f:(fun r ->
        of_yojson r
        |> Result.map_error ~f:(fun str ->
               Errors.erase @@ Errors.create (`Json_parse (Some str)) ) )

  let successfully r =
    match r with
    | Ok x ->
        Deferred.Result.return x
    | Error e ->
        Deferred.Result.fail
          (Errors.create
             ~context:(Rosetta_models.Error.show e)
             `Invariant_violation)

  let req ~logger:_ req :
      ( (Yojson.Safe.t, Rosetta_models.Error.t) result
      , Errors.t )
      Deferred.Result.t =
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
      | body -> (
        match Rosetta_models.Error.of_yojson body |> json with
        | Ok err ->
            Deferred.Result.return (Error err)
        | Error e ->
            Deferred.Result.fail e )
      | exception Yojson.Json_error err ->
          Deferred.Result.fail
            (Errors.create ~context:"Parsing Rosetta error"
               (`Json_parse (Some err))) )
end

let net_id network_response =
  List.hd_exn network_response.Network_list_response.network_identifiers

let post ~logger ~rosetta_uri ~body ~path =
  Cohttp_async.Client.post
    ~headers:
      Cohttp.Header.(init () |> fun t -> add t "Accept" "application/json")
    ~body:(body |> Yojson.Safe.to_string |> Cohttp_async.Body.of_string)
    (Uri.with_path rosetta_uri path)
  |> Lift.req ~logger

module Network = struct
  open Deferred.Result.Let_syntax

  let list ~rosetta_uri ~logger =
    let%bind res =
      post ~rosetta_uri ~logger
        ~body:Metadata_request.(create () |> to_yojson)
        ~path:"network/list"
    in
    Lift.res res ~logger ~of_yojson:Network_list_response.of_yojson
    |> Lift.successfully

  let status ~rosetta_uri ~network_response ~logger =
    let%map res =
      post ~rosetta_uri ~logger
        ~body:Network_request.(create (net_id network_response) |> to_yojson)
        ~path:"network/status"
    in
    Lift.res ~logger res ~of_yojson:Network_status_response.of_yojson
end

module Mempool = struct
  open Deferred.Result.Let_syntax

  let mempool ~rosetta_uri ~network_response ~logger =
    let%map res =
      post ~rosetta_uri ~logger
        ~body:Network_request.(create (net_id network_response) |> to_yojson)
        ~path:"mempool/"
    in
    Lift.res ~logger res ~of_yojson:Mempool_response.of_yojson

  let transaction ~rosetta_uri ~network_response ~logger ~hash =
    let%bind res =
      post ~rosetta_uri ~logger
        ~body:
          Mempool_transaction_request.(
            { network_identifier= net_id network_response
            ; transaction_identifier= {Transaction_identifier.hash} }
            |> to_yojson)
        ~path:"mempool/transaction"
    in
    Lift.res res ~logger ~of_yojson:Mempool_transaction_response.of_yojson
    |> Lift.successfully
end

module Block = struct
  open Deferred.Result.Let_syntax

  let request_block ~block_identifier ~rosetta_uri ~network_response ~logger =
    let%map res =
      post ~rosetta_uri ~logger
        ~body:
          Block_request.(
            create (net_id network_response) block_identifier |> to_yojson)
        ~path:"block/"
    in
    Lift.res ~logger res ~of_yojson:Block_response.of_yojson

  let newest_block ~rosetta_uri ~network_response ~logger =
    request_block
      ~block_identifier:(Partial_block_identifier.create ())
      ~rosetta_uri ~network_response ~logger

  let block_at_index ~index ~rosetta_uri ~network_response ~logger =
    request_block
      ~block_identifier:{index= Some index; hash= None}
      ~rosetta_uri ~network_response ~logger
end

module Construction = struct
  open Deferred.Result.Let_syntax

  let metadata ~rosetta_uri ~network_response ~logger ~options =
    let%bind res =
      post ~rosetta_uri ~logger
        ~body:
          Construction_metadata_request.(
            { network_identifier= net_id network_response
            ; options
            ; public_keys= [] }
            |> to_yojson)
        ~path:"construction/metadata"
    in
    Lift.res ~logger res ~of_yojson:Construction_metadata_response.of_yojson
    |> Lift.successfully

  (* This is really a poke, but collocating it here because it goes through rosetta *)
  let submit ~rosetta_uri ~network_response ~logger ~signed_transaction =
    let%bind res =
      post ~rosetta_uri ~logger
        ~body:
          Construction_submit_request.(
            {network_identifier= net_id network_response; signed_transaction}
            |> to_yojson)
        ~path:"construction/submit"
    in
    Lift.res ~logger res ~of_yojson:Construction_submit_response.of_yojson
    |> Lift.successfully
end

module Account_balance = struct
  open Deferred.Result.Let_syntax

  let request_balance ~account_identifier ~block_identifier ~rosetta_uri
      ~network_response ~logger =
    let request : Account_balance_request.t =
      { network_identifier= net_id network_response
      ; account_identifier
      ; block_identifier
      ; currencies= [] }
    in
    let%map res =
      post ~rosetta_uri ~logger
        ~body:(request |> Account_balance_request.to_yojson)
        ~path:"account/balance"
    in
    Lift.res ~logger res ~of_yojson:Account_balance_response.of_yojson

  let current_balance ~account_identifier ~rosetta_uri ~network_response
      ~logger =
    request_balance ~account_identifier ~block_identifier:None ~rosetta_uri
      ~network_response ~logger

  let balance_at_index ~account_identifier ~(index : int64) ~rosetta_uri
      ~network_response ~logger =
    request_balance ~account_identifier
      ~block_identifier:(Some {index= Some index; hash= None})
      ~rosetta_uri ~network_response ~logger
end
