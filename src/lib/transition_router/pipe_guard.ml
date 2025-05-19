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

  type identified_writer = { writer : writer; id : int }

  type control_msg =
    | ClosePipe of
        { result : [ `Closed_already_or_replaced | `Accepted ] Ivar.t
        ; id : int
        }
    | ReplacePipe of { writer : writer; id_returned : int Ivar.t }

  type state = { writer : identified_writer option; next_id : int }

  module Guard = Actor.Make (Data)

  let data_handler ~(state : state) ~(message : Data.t) =
    let rec wait_till_writer_ready () =
      match state.writer with
      | None ->
          let%bind () = Async.Scheduler.yield () in
          wait_till_writer_ready ()
      | Some writer_with_id ->
          Deferred.return writer_with_id
    in
    let%map writer_with_id = wait_till_writer_ready () in
    Strict_pipe.Writer.write writer_with_id.writer message ;
    Guard.Next state

  let control_handler ~(state : state) ~(message : control_msg) =
    Deferred.return
      ( match message with
      | ClosePipe { result; id = request_id } -> (
          match state.writer with
          | Some { id = held_id; writer } when held_id = request_id ->
              Strict_pipe.Writer.kill writer ;
              Ivar.fill result `Accepted ;
              Guard.Next { state with writer = None }
          | _ ->
              Ivar.fill result `Closed_already_or_replaced ;
              Guard.Next state )
      | ReplacePipe { writer; id_returned } ->
          Option.iter state.writer ~f:(fun { writer; _ } ->
              Strict_pipe.Writer.kill writer ) ;
          (* WARN:
             We know that the new writer provided is always valid because pipe
             guard would only receive ClosePipe after ReplacePipe. If that's not
             true we need to fix here.
          *)
          Ivar.fill id_returned state.next_id ;
          let writer = Some { writer; id = state.next_id } in
          Guard.Next { writer; next_id = state.next_id + 1 } )

  [%%define_locally Guard.(spawn, send_data, send_control)]

  let create ~logger () =
    Guard.create
      ~name:(`String "Valid Transition Pipe Guard")
        (* NOTE: We already have buffering in strict pipe, no point to further
                 buffer. Hence capacity is set to a very small number *)
      ~data_channel_type:(With_capacity (`Capacity 8, `Overflow Push_back))
      ~data_handler ~control_handler ~logger
      ~state:{ writer = None; next_id = 0 }
end
