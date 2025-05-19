open Core
open Async
open Pipe_lib

module Make (Data : sig
  type t

  val to_yojson : t -> Yojson.Safe.t
end) =
struct
  type writer =
    ( Data.t
    , Strict_pipe.drop_head Strict_pipe.buffered
    , unit )
    Strict_pipe.Writer.t

  module Request = struct
    type _ t =
      | ClosePipe : { id : int } -> [ `Closed_already_or_replaced | `Ok ] t
      | ReplacePipe : writer -> int t
  end

  type state = { writer : writer option; id : int }

  module Guard = Actor.WithRequest (Data) (Request)

  let data_handler ~(state : state) ~(message : Data.t) =
    Deferred.return
      ( match state.writer with
      | None ->
          Actor.MUnprocessed
      | Some writer ->
          Strict_pipe.Writer.write writer message ;
          Actor.MNext state )

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
        | { id = held_id; writer = Some writer } when held_id = request_id ->
            Strict_pipe.Writer.kill writer ;
            Deferred.return (Actor.RNext ({ state with writer = None }, `Ok))
        | _ ->
            Deferred.return (Actor.RNext (state, `Closed_already_or_replaced)) )
    | ReplacePipe writer ->
        Option.iter state.writer ~f:(fun writer ->
            Strict_pipe.Writer.kill writer ) ;
        (* WARN:
           We know that the new writer provided is always valid because pipe
           guard would only receive ClosePipe after ReplacePipe. If that's not
           true we need to fix here.
        *)
        let new_id = state.id + 1 in
        Deferred.return
          (Actor.RNext ({ writer = Some writer; id = new_id }, new_id))

  [%%define_locally Guard.(spawn, send_data, send_control, send_request)]

  let create ~logger () =
    Guard.create ~name:(`String "Valid Transition Pipe Guard")
      ~request_handler:{ f = request_handler }
      ~control_handler:Actor.DummyMessage.handler ~data_channel_type:Infinity
      ~data_handler ~logger ~state:{ writer = None; id = 0 }
end
