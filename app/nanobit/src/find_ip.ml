open Core
open Async
open Cohttp_async

type ip_service = { uri : string ; body_handler : string -> string; }

let services = [
  { uri = "https://api.ipify.org"; body_handler = Fn.id };
  { uri = "https://bot.whatismyipaddress.com"; body_handler = Fn.id };
  { uri = "http://ifconfig.co/ip"; body_handler = String.rstrip ~drop:(fun c -> c = '\n') }
];;

let find () =
  let handler : string option -> ip_service -> string option Deferred.t = fun acc elem -> match acc with
    | None ->
        let%bind (resp, body) = Client.get (Uri.of_string elem.uri) in
        Body.to_string body >>| elem.body_handler >>|
        (fun s -> if resp.status = `OK then Some s else None)
    | Some x -> return acc
  in (Deferred.List.fold services ~init:None ~f:handler >>|
    (fun x -> Option.value_exn ~message:"couldn't figure out own IP from the internet" x))
;;
