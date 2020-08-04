open Core_kernel
open Async_kernel
open Pipe_lib

module type S = sig
  type t

  type data

  val create : filename:string -> logger:Logger.t -> t Deferred.t

  val store : t -> data -> unit Deferred.t
end

module type Storage_intf = sig
  type data

  type location

  val store : location -> data -> unit Deferred.t
end

module Make (Data : sig
  type t
end)
(Store : Storage_intf with type location := string and type data := Data.t)
(Request : Web_request.Intf.S) : S with type data := Data.t = struct
  type t =
    { filename: string
    ; reader: Data.t Linear_pipe.Reader.t
    ; writer: Data.t Linear_pipe.Writer.t }

  let write_to_storage {filename; _} request data =
    let%bind () = Store.store filename data in
    Request.put request filename

  let create ~filename ~logger =
    let reader, writer = Linear_pipe.create () in
    let t = {filename; reader; writer} in
    let%map () =
      match%map Request.create () with
      | Ok request ->
          don't_wait_for
            (Linear_pipe.iter reader ~f:(fun data ->
                 match%map write_to_storage t request data with
                 | Ok () ->
                     ()
                 | Error e ->
                     [%log error] "Error writing Web client pipe data: $error"
                       ~metadata:[("error", `String (Error.to_string_hum e))]
             ))
      | Error e ->
          [%log error] "Unable to create request: %s" (Error.to_string_hum e)
    in
    t

  let store {reader; writer; _} data =
    Linear_pipe.force_write_maybe_drop_head ~capacity:1 writer reader data ;
    Deferred.unit
end
