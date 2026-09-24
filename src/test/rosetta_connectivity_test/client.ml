(* JSON-over-HTTP POST with the latency of each call. *)

open Core
open Async

type response =
  { status : int; body : Yojson.Safe.t option; latency : Time_ns.Span.t }

let headers =
  Cohttp.Header.of_list
    [ ("Accept", "application/json"); ("Content-Type", "application/json") ]

let post ?(timeout = Time.Span.of_sec 30.) uri json =
  let start = Time_ns.now () in
  let request =
    let%bind response, body =
      Cohttp_async.Client.post ~headers
        ~body:(Cohttp_async.Body.of_string (Yojson.Safe.to_string json))
        uri
    in
    let%map body = Cohttp_async.Body.to_string body in
    (response, body)
  in
  match%map
    Clock.with_timeout timeout
      (* Conduit can raise a second error into the same monitor (socket close
         after a refused connect, or after [timeout] gave up on the call);
         the first one already decided the outcome. *)
      (Monitor.try_with ~extract_exn:true ~rest:(`Call ignore) (fun () ->
           request ) )
  with
  | `Timeout ->
      Or_error.errorf "POST %s: no response in %s" (Uri.to_string uri)
        (Time.Span.to_string_hum timeout)
  | `Result (Error exn) ->
      Or_error.errorf "POST %s: %s" (Uri.to_string uri) (Exn.to_string exn)
  | `Result (Ok (response, body)) ->
      let latency = Time_ns.diff (Time_ns.now ()) start in
      let status =
        Cohttp.Code.code_of_status (Cohttp.Response.status response)
      in
      Ok
        { status
        ; body = Option.try_with (fun () -> Yojson.Safe.from_string body)
        ; latency
        }

(* [path json ["a"; "b"]] is json.a.b; a number segment indexes an array. *)
let rec path json = function
  | [] ->
      Some json
  | key :: rest -> (
      match (json, Option.try_with (fun () -> Int.of_string key)) with
      | `List items, Some i ->
          List.nth items i |> Option.bind ~f:(fun j -> path j rest)
      | `Assoc fields, _ ->
          List.Assoc.find fields ~equal:String.equal key
          |> Option.bind ~f:(fun j -> path j rest)
      | _ ->
          None )

let string_at json keys =
  match path json keys with Some (`String s) -> Some s | _ -> None
