open Core


module type ENDPOINT = sig
  type t
  
  val uri : string
  val query : Yojson.Safe.t
  val of_json : Yojson.t -> (t, exn) Result.t
  val to_string : t -> string
end

let report_error = function
  | (Unix.Unix_error (Unix.ECONNREFUSED, fn, arg)) ->
     Async.Print.eprintf "Connection refused in %s(%s)" fn arg
  | Json.Invalid es ->
     List.iter es ~f:(fun (msg, json) ->
       Async.Print.eprintf "%s (%s)\n" msg (Yojson.to_string json))
  | e ->
     Async.Print.eprintf "Unrecognised exception: %s!\n" (Exn.to_string e)

let handle_error = function
  | Ok msg ->
     Async.Print.printf "%s" msg
  | Error e ->
     report_error e

let call (type t) ~conf (module E : ENDPOINT with type t = t) =
  let open Async.Deferred.Let_syntax in
  let body = Cohttp_async.Body.of_string @@ Yojson.Safe.to_string E.query in
  let%map json = Async.try_with ~extract_exn:true (fun () ->
      let%bind (_resp, body) =
        Cohttp_async.Client.post ~body (Conf.rosetta_url conf E.uri)
      in
      let%map resp_str = Cohttp_async.Body.to_string body in
      Yojson.Raw.from_string resp_str)
  in
  Result.bind (json :> (Yojson.t, exn) Result.t) ~f:E.of_json

let call_and_display (type t) ~conf (module E : ENDPOINT with type t = t) () =
  let open Async.Deferred.Let_syntax in
  let%map r = call ~conf (module E) in
  handle_error (Result.map ~f:E.to_string r)
