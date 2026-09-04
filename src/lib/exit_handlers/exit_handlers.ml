(* exit_handlers -- coordinated, tiered daemon shutdown *)

open Core_kernel
open Async_kernel
open Async_unix

(* Shutdown tiers, listed in execution order.
   At shutdown, all handlers in the first tier run sequentially to completion,
   then all handlers in the second tier, and so on. *)
type shutdown_tier =
  | FlushPersistentFrontier
  | DestroyConfigAndLedgers
  | ReleaseDaemonLockfile
[@@deriving equal, enumerate]

(* Handlers accumulate in reverse registration order (cons-list) *)
let handlers : (shutdown_tier * (unit -> unit Deferred.t)) list ref = ref []

let initialized = ref false

let run_shutdown_handlers () =
  Deferred.List.iter all_of_shutdown_tier ~f:(fun tier ->
      let tier_handlers =
        List.filter_map (List.rev !handlers) ~f:(fun (t, f) ->
            if equal_shutdown_tier t tier then Some f else None )
      in
      Deferred.List.iter tier_handlers ~f:(fun f -> f ()) )

let ensure_shutdown_hook_registered () =
  if not !initialized then (
    initialized := true ;
    Shutdown.at_shutdown run_shutdown_handlers )

(* register a Deferred.t thunk to be called at Async shutdown in the given
   tier; log registration and execution *)
let register_async_shutdown_handler ~logger ~description ~tier
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
  ensure_shutdown_hook_registered () ;
  handlers := (tier, logging_thunk) :: !handlers

module For_testing = struct
  let run_shutdown_handlers = run_shutdown_handlers

  let reset () =
    handlers := [] ;
    initialized := false
end
