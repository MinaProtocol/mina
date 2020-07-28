(** Observing the state of the network through the lens of Rosetta *)

open Async
open Core_kernel
open Models
open Lib

let lift req =
  let open Deferred.Let_syntax in
  let%bind response, body = req in
  let%map str = Cohttp_async.Body.to_string body in
  match Cohttp_async.Response.status response with
  | `OK -> (
    try Yojson.Safe.from_string str |> Result.return
    with _ -> Result.fail (Errors.create (`Json_parse None)) )
  | _ ->
      Result.fail
        (Errors.create
           ~context:(sprintf "Rosetta error: %s" str)
           `Invariant_violation)

module Network = struct
  (* TODO: Catch errors *)
  let list ~rosetta_uri =
    Cohttp_async.Client.post
      ~headers:
        Cohttp.Header.(init () |> fun t -> add t "Accept" "application/json")
      ~body:
        ( Metadata_request.create () |> Metadata_request.to_yojson
        |> Yojson.Safe.to_string |> Cohttp_async.Body.of_string )
      (Uri.with_path rosetta_uri "network/list")
    |> lift
end
