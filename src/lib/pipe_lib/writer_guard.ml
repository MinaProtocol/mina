open Core
open Async

module Make (Inputs : sig
  module Data : sig
    type t

    val to_yojson : t -> Yojson.Safe.t
  end

  val capacity : int

  type aux

  val callback : aux option -> Data.t -> unit
end) =
struct
  include Inputs

  (* Buffering behaviors should go directly into channel type *)
  type writer =
    (Data.t, Strict_pipe.synchronous, unit Deferred.t) Strict_pipe.Writer.t

  type writer_with_aux = { writer : writer; aux : aux }

  type state = { writer_with_aux : writer_with_aux option; id : int }

  let drop_and_call_callback (state : state) (data : Data.t) =
    let aux_opt = Option.map ~f:(fun w -> w.aux) state.writer_with_aux in
    callback aux_opt data

  let channel_type =
    Actor.With_capacity
      (`Capacity capacity, `Overflow (Drop_and_call_head drop_and_call_callback))

  module Request = struct
    type _ t =
      | ClosePipe : { id : int } -> [ `Closed_already_or_replaced | `Ok ] t
      | ReplacePipe : writer_with_aux -> int t
  end

  module Guard = Actor.WithRequest (Data) (Request)

  let data_handler ~(state : state) ~(message : Data.t) =
    match state.writer_with_aux with
    | None ->
        Deferred.return Actor.MUnprocessed
    | Some { writer; _ } ->
        let%map () = Strict_pipe.Writer.write writer message in
        Actor.MNext state

  let request_handler :
      type response.
         state:state
      -> request:response Request.t
      -> (state, response) Actor.req_processed Deferred.t =
   fun ~state ~request ->
    let open Request in
    match request with
    | ClosePipe { id = request_id } -> (
        match state with
        | { id = held_id; writer_with_aux = Some { writer; _ } }
          when held_id = request_id ->
            Strict_pipe.Writer.kill writer ;
            Deferred.return
              (Actor.RNext ({ state with writer_with_aux = None }, `Ok))
        | _ ->
            Deferred.return (Actor.RNext (state, `Closed_already_or_replaced)) )
    | ReplacePipe writer_with_aux ->
        Option.iter state.writer_with_aux ~f:(fun { writer; _ } ->
            Strict_pipe.Writer.kill writer ) ;
        (* WARN:
           We know that the new writer provided is always valid because pipe
           guard would only receive ClosePipe after ReplacePipe. If that's not
           true we need to fix here.
        *)
        let new_id = state.id + 1 in
        Deferred.return
          (Actor.RNext
             ({ writer_with_aux = Some writer_with_aux; id = new_id }, new_id)
          )

  [%%define_locally Guard.(spawn, send_data, send_control, send_request)]

  let create ~logger () =
    Guard.create ~name:(`String "Valid Transition Pipe Guard")
      ~request_handler:{ f = request_handler }
      ~control_handler:Actor.DummyMessage.handler
      ~data_channel_type:channel_type ~data_handler ~logger
      ~state:{ writer_with_aux = None; id = 0 }
end
