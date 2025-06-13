(* exit_handlers -- code to call at daemon exit *)

open Core_kernel
open Async_kernel
open Async_unix

(* register a Deferred.t thunk to be called at Async shutdown; log registration
   and execution *)
let register_async_shutdown_handler ~logger ~description
    (f : unit -> unit Deferred.t) =
  [%log debug] "Registering async shutdown handler: $description"
    ~metadata:[ ("description", `String description) ] ;
  let logging_thunk () =
    [%log info] "Running async shutdown handler: $description"
      ~metadata:[ ("description", `String description) ] ;
    let open Deferred.Let_syntax in
    let%map () =
      match%map Monitor.try_with ~here:[%here] ~extract_exn:true f with
      | Ok () ->
          ()
      | Error exn ->
          [%log info]
            "When running async shutdown handler: $description, got exception \
             $exn"
            ~metadata:
              [ ("description", `String description)
              ; ("exn", `String (Exn.to_string exn))
              ]
    in
    ()
  in
  Shutdown.at_shutdown logging_thunk
