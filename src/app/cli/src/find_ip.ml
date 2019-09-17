open Core
open Async
open Cohttp_async

type ip_service = {uri: string; body_handler: string -> string}

let services =
  [ {uri= "https://api.ipify.org"; body_handler= Fn.id}
  ; {uri= "https://bot.whatismyipaddress.com"; body_handler= Fn.id}
  ; { uri= "http://ifconfig.co/ip"
    ; body_handler= String.rstrip ~drop:(fun c -> c = '\n') } ]

let ip_service_result {uri; body_handler} =
  let%bind resp, body = Client.get (Uri.of_string uri) in
  Body.to_string body >>| body_handler
  >>| fun s -> if resp.status = `OK then Some s else None

let find () =
  let handler acc elem =
    match acc with None -> ip_service_result elem | Some _ -> return acc
  in
  Deferred.List.fold services ~init:None ~f:handler
  >>| fun x ->
  Unix.Inet_addr.of_string
  @@ Option.value_exn ~message:"couldn't determine our IP from the internet" x
