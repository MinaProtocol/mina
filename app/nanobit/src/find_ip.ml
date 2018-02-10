open Core
open Async
open Cohttp_async


let uri = Uri.of_string "https://api.ipify.org"

let find () =
  let%bind (_resp, body) = Client.get uri in
  Body.to_string body
;;
