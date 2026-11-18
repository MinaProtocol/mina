(* A local HTTP server that answers like a bucket of block files. *)

open Core
open Async

let block_path = "/mainnet-5-3NKabc.json"

let block_body = {|{"block":"content"}|}

let not_found_body =
  {|<?xml version='1.0' encoding='UTF-8'?><Error><Code>NoSuchKey</Code></Error>|}

(* The answer of a public bucket to a listing of [prefix]. It has the files
   of the network mainnet, also under the key path sub/. *)
let listing_body ~prefix =
  let key =
    if List.mem [ "mainnet-"; "sub/mainnet-" ] prefix ~equal:String.equal then
      sprintf "<Contents><Key>%s5-3NKabc.json</Key></Contents>" prefix
    else ""
  in
  sprintf
    {|<?xml version='1.0' encoding='UTF-8'?><ListBucketResult><Prefix>%s</Prefix>%s</ListBucketResult>|}
    prefix key

(* Serves [block_path], a bucket that lists its files at /listed/ and a page
   at /plain/. Answers 403 at the root like a private bucket, and 404 to
   every other path. *)
let with_server f =
  Thread_safe.block_on_async_exn (fun () ->
      let%bind server =
        Cohttp_async.Server.create ~on_handler_error:`Raise
          Tcp.Where_to_listen.of_port_chosen_by_os (fun ~body:_ _ request ->
            let uri = Cohttp.Request.uri request in
            match Uri.path uri with
            | path when String.equal path block_path ->
                Cohttp_async.Server.respond_string block_body
            | "/" ->
                Cohttp_async.Server.respond_string ~status:`Forbidden "denied"
            | "/listed/" ->
                Cohttp_async.Server.respond_string
                  (listing_body
                     ~prefix:
                       (Option.value_exn (Uri.get_query_param uri "prefix")) )
            | "/plain/" ->
                Cohttp_async.Server.respond_string "<html>blocks</html>"
            | _ ->
                Cohttp_async.Server.respond_string ~status:`Not_found
                  not_found_body )
      in
      let url =
        sprintf "http://127.0.0.1:%d" (Cohttp_async.Server.listening_on server)
      in
      let%bind dir = Unix.mkdtemp "/tmp/missing_blocks_guardian_test" in
      let%bind result = f ~url ~dir in
      let%map () = Cohttp_async.Server.close server in
      result )
