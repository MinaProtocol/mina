open Core_kernel
open Async_kernel

(** short-lived sink: a writer for a pipe which was created upon
    a call to [swap_reader]. *)
type 'data_in_pipe short_lived_sink_t =
  ('data_in_pipe, Strict_pipe.synchronous, unit Deferred.t) Strict_pipe.Writer.t

type ('data_in_pipe, 'write_return) t =
  | Swappable :
      { long_lived_writer :
          ('data_in_pipe, 'pipe_kind, 'write_return) Strict_pipe.Writer.t
            (** If [termination_signal] is filled, the swappable pipe is
          set to gracefully terminate.
        *)
      ; termination_signal : unit Ivar.t
            (** mutable variable [next_short_lived_sink] is only written from
          within the [background_thread]. It contains an [Ivar.t] of a pair.
          First element of the pair is short lived sink which will become the
          next sink. Second element of the pair is a "push-back" of type
          [unit Ivar.t] which is filled once the swapping is done. *)
      ; mutable next_short_lived_sink :
          ('data_in_pipe short_lived_sink_t * unit Ivar.t) Ivar.t
      }
      -> ('data_in_pipe, 'write_return) t

(** state of the swappable pipe

    Used by the background thread, every iteration of the loop
    returns an updated state (fields [short_lived_sink] and [data_unconsumed]
    are updated).
*)
type ('data_in_pipe, 'write_return) state_t =
  { name : string
  ; long_lived_reader : 'data_in_pipe Strict_pipe.Reader.t
  ; exposed : ('data_in_pipe, 'write_return) t
  ; short_lived_sink : 'data_in_pipe short_lived_sink_t option
  ; data_unconsumed : 'data_in_pipe option
  }

(** Terminates the swappable pipe.

    Shouldn't be called more than once for a pipe.
*)
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

(** Returns a choice that terminates the pipe when the termination signal is filled.
    
    If choice is fullfilled, [Finished ()] is returned to signal [background_thread]
    to exit.
*)
let terminate_choice state =
  let (Swappable { termination_signal; _ }) = state.exposed in
  choice (Ivar.read termination_signal) (fun () -> terminate state)

let handle_next_short_lived_sink state (new_sink, processed_signal) =
  let (Swappable t) = state.exposed in
  t.next_short_lived_sink <- Ivar.create () ;
  Ivar.fill processed_signal () ;
  Option.iter ~f:Strict_pipe.Writer.kill state.short_lived_sink ;
  `Repeat { state with short_lived_sink = Some new_sink }

(** Returns a choice that updates state with a new short-lived sink
    when the next short-lived sink is available.
*)
let read_short_lived_sink_choice state =
  let (Swappable t) = state.exposed in
  choice
    (Ivar.read t.next_short_lived_sink)
    (handle_next_short_lived_sink state)

(** Returns a choice that writes data to the short-lived sink and
    returns [`Repeat] with updated state (with [data_unconsumed]
    set to [None]).
*)
let write_sink_choice ~sink ~data state =
  (* TODO: potential concurrency bug: if this choice is not selected,
     write may happen twice (on a previous and next short-lived sinks simultaneously) *)
  choice (Strict_pipe.Writer.write sink data) (fun () ->
      `Repeat { state with data_unconsumed = None } )

(** Attempt to write data to the short-lived sink.
    
    If the pipe is terminated, [`Finished ()] is returned.
    If write follows through, [`Repeat] is returned with updated state
    (with [data_unconsumed] set to [None]).
    If the next short-lived sink is available, [`Repeat] is returned with updated state
    (with [short_lived_sink] set to [Some sink]).

    There is no guarantee on the order of the choices. Behavior
    of [Deferred.choice] guarantees that the result is determined in the
    async cycle if any of the choices becomes determined.
*)
let short_lived_write state sink data =
  choose
    [ terminate_choice state
    ; write_sink_choice ~sink ~data state
    ; read_short_lived_sink_choice state
    ]

(** Attempt to read next short-lived sink.
    
    If the pipe is terminated, [`Finished ()] is returned.
    If the next short-lived sink is available, [`Repeat] is returned with updated state
    (with [short_lived_sink] set to [Some sink]).

    There is no guarantee on the order of the choices. Behavior
    of [Deferred.choice] guarantees that the result is determined in the
    async cycle if any of the choices becomes determined.
*)
let read_short_lived_sink state =
  choose [ terminate_choice state; read_short_lived_sink_choice state ]

(** Attempt to read from the long-lived reader.
    
    If the pipe is terminated, [`Finished ()] is returned.
    If the long-lived reader has data, [`Repeat] is returned with updated state
    (with [data_unconsumed] set to [Some data]).

    There is no guarantee on the order of the choices. Behavior
    of [Deferred.choice] guarantees that the result is determined in the
    async cycle if any of the choices becomes determined.
*)
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

(** Step the background thread.
    
    If the pipe is terminated, [`Finished ()] is returned.
    If the next short-lived sink is available, swap will be performed.

    It's guaranteed that the two choices above will be validated
    before others.

    If the long-lived reader has data, it will be read into the state.
    If the short-lived sink is available, and some data was read,
    it will be written to the short-lived sink.

    Function [step] performs at most one asynchronous
    operation per call (always via [Deferred.choose]).
*)
let step (state : _ state_t) =
  let (Swappable t) = state.exposed in
  match
    ( state.data_unconsumed
    , state.short_lived_sink
    , Ivar.peek t.next_short_lived_sink )
  with
  (* If the swappable pipe is terminated, we are done *)
  | _ when Ivar.is_full t.termination_signal ->
      Deferred.return (terminate state)
  | _, _, Some new_sink_and_signal ->
      Deferred.return (handle_next_short_lived_sink state new_sink_and_signal)
  | _, None, _ ->
      read_short_lived_sink state
  | None, Some _, _ ->
      read_long_lived state
  | Some data, Some short_lived_sink, _ ->
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

module Iterator = struct
  type 'data_in_pipe t = 'data_in_pipe Strict_pipe.Reader.t

  [%%define_locally Strict_pipe.Reader.(read, iter)]
end

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
       concurrency bug, though it's safe in single-threaded ocaml execution.

       Recommendation: have alternative to [fill_if_empty] that doesn't
       that returns a boolean with whether the fill was successful.
    *)
    let processed_signal = Ivar.create () in
    Ivar.fill t.next_short_lived_sink (short_lived_writer, processed_signal) ;
    let%map () = Ivar.read processed_signal in
    short_lived_reader

let kill (Swappable t) = Ivar.fill_if_empty t.termination_signal ()
