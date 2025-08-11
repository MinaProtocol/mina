(* exit_handlers -- code to call at daemon exit *)

open Core_kernel
open Async_kernel
open Async_unix

module Priority = struct
  type t =
    | Normal
        (** default handler level, ran before exclusion cleanup is issued *)
    | Hardfork_config
        (** ran after all other components of mina is closed, so to avoid race condition *)
    (* TODO: when we're actually trying to pull hardfork config from running DB,
       we need to put this priority higher than `Normal`. For now since we're
       just copying the folder, it should be at this level. *)
    | Exclusion
        (** after such cleanup is ran, a new execution of program could be started *)
  [@@deriving compare]
end

module Handler = struct
  type t =
    { priority : Priority.t
    ; description : string
    ; thunk : unit -> unit Deferred.t
    ; logger : Logger.t
    }

  let compare { priority = p1; _ } { priority = p2; _ } = Priority.compare p1 p2
end

(* register a Deferred.t thunk to be called at Async shutdown; log registration
   and execution *)
let register_async_shutdown_handler =
  let (registered_thunks : Handler.t Queue.t) = Queue.create () in
  Shutdown.at_shutdown (fun () ->
      Queue.to_list registered_thunks
      |> List.sort ~compare:Handler.compare
      |> List.map ~f:(fun { description; thunk; logger; _ } ->
             [%log info] "Running async shutdown handler: $description"
               ~metadata:[ ("description", `String description) ] ;
             match%map
               Monitor.try_with ~here:[%here] ~extract_exn:true thunk
             with
             | Ok () ->
                 ()
             | Error exn ->
                 [%log info]
                   "When running async shutdown handler: $description, got \
                    exception $exn"
                   ~metadata:
                     [ ("description", `String description)
                     ; ("exn", `String (Exn.to_string exn))
                     ] )
      |> Deferred.all |> Deferred.ignore_m ) ;
  fun ~logger ~description ?(priority = Priority.Normal)
      (thunk : unit -> unit Deferred.t) ->
    [%log debug] "Registering async shutdown handler: $description"
      ~metadata:[ ("description", `String description) ] ;
    Queue.enqueue registered_thunks
      Handler.{ priority; description; thunk; logger }
