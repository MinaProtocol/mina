open Core_kernel
open Async_kernel

type 'data_in_pipe short_lived_sink_t =
  ('data_in_pipe, Strict_pipe.synchronous, unit Deferred.t) Strict_pipe.Writer.t

type ('data_in_pipe, 'write_return) t =
  | Swappable :
      { long_lived_writer :
          ('data_in_pipe, 'pipe_kind, 'write_return) Strict_pipe.Writer.t
      ; termination_signal : unit Ivar.t
            (** mutable variable [next_short_lived_sink] is only written from
          within the [background_thread] *)
      ; mutable next_short_lived_sink :
          ('data_in_pipe short_lived_sink_t * unit Ivar.t) Ivar.t
      }
      -> ('data_in_pipe, 'write_return) t

type ('data_in_pipe, 'write_return) state_t =
  { name : string
  ; long_lived_reader : 'data_in_pipe Strict_pipe.Reader.t
  ; short_lived_sink : 'data_in_pipe short_lived_sink_t option
  ; data_unconsumed : 'data_in_pipe option
  ; exposed : ('data_in_pipe, 'write_return) t
  }

let terminate state =
  let (Swappable { long_lived_writer; next_short_lived_sink; _ }) =
    state.exposed
  in
  Strict_pipe.Writer.kill long_lived_writer ;
  Option.iter ~f:Strict_pipe.Writer.kill state.short_lived_sink ;
  Option.iter (Ivar.peek next_short_lived_sink)
    ~f:(fun (writer, processed_signal) ->
      Strict_pipe.Writer.kill writer ;
      Ivar.fill processed_signal () ) ;
  `Finished ()

let terminate_choice state =
  let (Swappable { termination_signal; _ }) = state.exposed in
  choice (Ivar.read termination_signal) (fun () -> terminate state)

let read_short_lived_sink_choice state =
  let (Swappable t) = state.exposed in
  choice (Ivar.read t.next_short_lived_sink)
    (fun (new_sink, processed_signal) ->
      t.next_short_lived_sink <- Ivar.create () ;
      Ivar.fill processed_signal () ;
      Option.iter ~f:Strict_pipe.Writer.kill state.short_lived_sink ;
      `Repeat { state with short_lived_sink = Some new_sink } )

let write_sink_choice ~sink ~data state =
  choice (Strict_pipe.Writer.write sink data) (fun () ->
      `Repeat { state with data_unconsumed = None } )

let short_lived_write state sink data =
  choose
    [ terminate_choice state
    ; write_sink_choice ~sink ~data state
    ; read_short_lived_sink_choice state
    ]

let read_short_lived_sink state =
  choose [ terminate_choice state; read_short_lived_sink_choice state ]

let read_long_lived state =
  choose
    [ terminate_choice state
    ; choice (Strict_pipe.Reader.read state.long_lived_reader) (function
        (* Only may happen due to termination, repeating to exit gracefully *)
        | `Eof ->
            `Repeat state
        | `Ok x ->
            `Repeat { state with data_unconsumed = Some x } )
    ]

let step (state : _ state_t) =
  let (Swappable { termination_signal; _ }) = state.exposed in
  match (state.data_unconsumed, state.short_lived_sink) with
  (* If the swappable pipe is terminated, we are done *)
  | _ when Ivar.is_full termination_signal ->
      Deferred.return (terminate state)
  | _, None ->
      read_short_lived_sink state
  | None, Some _ ->
      read_long_lived state
  | Some data, Some short_lived_sink ->
      short_lived_write state short_lived_sink data

let background_thread ~name (t : _ state_t) =
  O1trace.background_thread (name ^ "-swappable") (fun () ->
      Deferred.repeat_until_finished t step )

let create ?warn_on_drop ~name type_ =
  let long_lived_reader, long_lived_writer =
    Strict_pipe.create ~name ?warn_on_drop type_
  in
  let exposed =
    Swappable
      { long_lived_writer
      ; termination_signal = Ivar.create ()
      ; next_short_lived_sink = Ivar.create ()
      }
  in
  let state =
    { name
    ; long_lived_reader
    ; exposed
    ; short_lived_sink = None
    ; data_unconsumed = None
    }
  in
  background_thread ~name state ;
  exposed

let write (Swappable { long_lived_writer; _ }) =
  Strict_pipe.Writer.write long_lived_writer

let swap_reader ~reader_name (Swappable t) =
  let short_lived_reader, short_lived_writer =
    Strict_pipe.create ~name:reader_name Synchronous
  in
  (* If the pipe is terminated, an immediately closed reader is returned.
     If [t.next_short_lived_sink] is full, it means there was a race
     (within the same async cycle) between two calls to [swap_reader],
     and the first-that-came wins, while for later calls an immediately closed
     reader is returned.
  *)
  if Ivar.is_full t.termination_signal || Ivar.is_full t.next_short_lived_sink
  then (
    Strict_pipe.Writer.kill short_lived_writer ;
    Deferred.return short_lived_reader )
  else
    (* TODO when rewriting to Ocaml 5.x, the "else" case may result in a
           concurrency bug, though it's safe in single-threaded ocaml execution
    *)
    let processed_signal = Ivar.create () in
    Ivar.fill t.next_short_lived_sink (short_lived_writer, processed_signal) ;
    let%map () = Ivar.read processed_signal in
    short_lived_reader

let kill (Swappable t) = Ivar.fill_if_empty t.termination_signal ()
