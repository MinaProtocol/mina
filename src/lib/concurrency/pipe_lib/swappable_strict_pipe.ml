open Core_kernel
open Async_kernel

(** short-lived pipe: an [Ivar.t] that is filled with an [Ivar.t] 
    to which some data can be put.
    
    Usage: reader fills the outer ivar with an empty ivar and
    then waits for that one to be filled with data and the new ivar
    that can be used in the same way (or `Eof if the pipe is terminated).
    *)
type 'data_in_pipe short_lived_pipe_t =
  | Short_lived_pipe of
      [ `Eof | `Ok of 'data_in_pipe * 'data_in_pipe short_lived_pipe_t ] Ivar.t
      Ivar.t

type ('data_in_pipe, 'write_return) t =
  | Swappable :
      { long_lived_writer :
          ('data_in_pipe, 'pipe_kind, 'write_return) Strict_pipe.Writer.t
            (** If [termination_signal] is filled, the swappable pipe is
          set to gracefully terminate.
        *)
      ; termination_signal : unit Ivar.t
            (** mutable variable [next_short_lived_pipe] is only written from
          within the [background_thread]. It contains an [Ivar.t] of a pair.
          First element of the pair is short lived sink which will become the
          next sink. Second element of the pair is a "push-back" of type
          [unit Ivar.t] which is filled once the swapping is done. *)
      ; mutable next_short_lived_pipe :
          ('data_in_pipe short_lived_pipe_t * unit Ivar.t) Ivar.t
      }
      -> ('data_in_pipe, 'write_return) t

(** state of the swappable pipe

    Used by the background thread, every iteration of the loop
    returns an updated state (fields [short_lived_pipe] and [data_unconsumed]
    are updated).
*)
type ('data_in_pipe, 'write_return) state_t =
  { name : string
  ; long_lived_reader : 'data_in_pipe Strict_pipe.Reader.t
  ; exposed : ('data_in_pipe, 'write_return) t
  ; short_lived_pipe : 'data_in_pipe short_lived_pipe_t option
  ; data_unconsumed : 'data_in_pipe option
  }

(** Terminates the short-lived pipe.
    Ensures that any reader on it will get [`Eof].
*)
let terminate_short_lived_pipe (Short_lived_pipe outer_ivar) =
  Ivar.fill_if_empty outer_ivar (Ivar.create_full `Eof) ;
  Option.iter (Ivar.peek outer_ivar) ~f:(Fn.flip Ivar.fill_if_empty `Eof)

(** Terminates the swappable pipe.

    Shouldn't be called more than once for a pipe.
*)
let terminate state =
  let (Swappable { long_lived_writer; next_short_lived_pipe; _ }) =
    state.exposed
  in
  Strict_pipe.Writer.kill long_lived_writer ;
  Option.iter ~f:terminate_short_lived_pipe state.short_lived_pipe ;
  Option.iter (Ivar.peek next_short_lived_pipe)
    ~f:(fun (writer, processed_signal) ->
      terminate_short_lived_pipe writer ;
      Ivar.fill processed_signal () ) ;
  `Finished ()

(** Returns a choice that terminates the pipe when the termination signal is filled.
    
    If choice is fullfilled, [Finished ()] is returned to signal [background_thread]
    to exit.
*)
let terminate_choice state =
  let (Swappable { termination_signal; _ }) = state.exposed in
  choice (Ivar.read termination_signal) (fun () -> terminate state)

let handle_next_short_lived_pipe state (new_sink, processed_signal) =
  let (Swappable t) = state.exposed in
  t.next_short_lived_pipe <- Ivar.create () ;
  Ivar.fill processed_signal () ;
  Option.iter ~f:terminate_short_lived_pipe state.short_lived_pipe ;
  `Repeat { state with short_lived_pipe = Some new_sink }

(** Returns a choice that updates state with a new short-lived sink
    when the next short-lived sink is available.
*)
let read_short_lived_pipe_choice state =
  let (Swappable t) = state.exposed in
  choice
    (Ivar.read t.next_short_lived_pipe)
    (handle_next_short_lived_pipe state)

(** Returns a choice that writes data to the short-lived sink and
    returns [`Repeat] with updated state (with [data_unconsumed]
    set to [None]).

    No write actually happens if the choice wasn't selected,
    so it's safe to call use the choice repeatedly, until
    the choice is actually selected (then a single write happens).
*)
let write_sink_choice ~sink ~data state =
  choice (Ivar.read sink) (fun ivar ->
      let new_sink = Short_lived_pipe (Ivar.create ()) in
      Ivar.fill_if_empty ivar (`Ok (data, new_sink)) ;
      `Repeat
        { state with data_unconsumed = None; short_lived_pipe = Some new_sink } )

(** Attempt to write data to the short-lived sink.
    
    If the pipe is terminated, [`Finished ()] is returned.
    If write follows through, [`Repeat] is returned with updated state
    (with [data_unconsumed] set to [None]).
    If the next short-lived sink is available, [`Repeat] is returned with updated state
    (with [short_lived_pipe] set to [Some sink]).

    There is no guarantee on the order of the choices. Behavior
    of [Deferred.choice] guarantees that the result is determined in the
    async cycle if any of the choices becomes determined.
*)
let short_lived_write state (Short_lived_pipe sink) data =
  choose
    [ terminate_choice state
    ; write_sink_choice ~sink ~data state
    ; read_short_lived_pipe_choice state
    ]

(** Attempt to read next short-lived sink.
    
    If the pipe is terminated, [`Finished ()] is returned.
    If the next short-lived sink is available, [`Repeat] is returned with updated state
    (with [short_lived_pipe] set to [Some sink]).

    There is no guarantee on the order of the choices. Behavior
    of [Deferred.choice] guarantees that the result is determined in the
    async cycle if any of the choices becomes determined.
*)
let read_short_lived_pipe state =
  choose [ terminate_choice state; read_short_lived_pipe_choice state ]

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
let step (type data_in_pipe write_return)
    (state : (data_in_pipe, write_return) state_t) =
  let (Swappable t) = state.exposed in
  match
    ( state.data_unconsumed
    , state.short_lived_pipe
    , Ivar.peek t.next_short_lived_pipe )
  with
  (* If the swappable pipe is terminated, we are done *)
  | _ when Ivar.is_full t.termination_signal ->
      Deferred.return (terminate state)
  | _, _, Some new_sink_and_signal ->
      Deferred.return (handle_next_short_lived_pipe state new_sink_and_signal)
  | _, None, _ ->
      read_short_lived_pipe state
  | None, Some _, _ ->
      read_long_lived state
  | Some data, Some short_lived_pipe, _ ->
      short_lived_write state short_lived_pipe data

let background_thread ~name (t : _ state_t) =
  O1trace.background_thread (name ^ "-swappable") (fun () ->
      Deferred.repeat_until_finished t step )

let create (type data_in_pipe pipe_kind write_return) ?warn_on_drop ~name
    (type_ : (data_in_pipe, pipe_kind, write_return) Strict_pipe.type_) :
    (data_in_pipe, write_return) t =
  let long_lived_reader, long_lived_writer =
    Strict_pipe.create ~name ?warn_on_drop type_
  in
  let exposed =
    Swappable
      { long_lived_writer
      ; termination_signal = Ivar.create ()
      ; next_short_lived_pipe = Ivar.create ()
      }
  in
  let state =
    { name
    ; long_lived_reader
    ; exposed
    ; short_lived_pipe = None
    ; data_unconsumed = None
    }
  in
  background_thread ~name state ;
  exposed

let write (Swappable { long_lived_writer; _ }) =
  Strict_pipe.Writer.write long_lived_writer

module Iterator = struct
  type 'data_in_pipe t = 'data_in_pipe short_lived_pipe_t

  let read_one (Short_lived_pipe outer_ivar : _ t) =
    Ivar.fill_if_empty outer_ivar (Ivar.create ()) ;
    let inner_ivar =
      Ivar.peek outer_ivar
      |> Option.value_exn
           ~message:"unexpected condition in swappable pipe's iterator"
    in
    Ivar.read inner_ivar

  let iter (t_initial : _ t) ~f =
    Deferred.repeat_until_finished t_initial (fun t ->
        match%bind read_one t with
        | `Eof ->
            Deferred.return (`Finished ())
        | `Ok (data, t') ->
            f data >>| fun () -> `Repeat t' )
end

let swap_reader (Swappable t) : _ Iterator.t Deferred.t =
  (* If the pipe is terminated, an immediately closed reader is returned.
     If [t.next_short_lived_pipe] is full, it means there was a race
     (within the same async cycle) between two calls to [swap_reader],
     and the first-that-came wins, while for later calls an immediately closed
     reader is returned.
  *)
  if Ivar.is_full t.termination_signal || Ivar.is_full t.next_short_lived_pipe
  then
    Deferred.return (Short_lived_pipe (Ivar.create_full (Ivar.create_full `Eof)))
  else
    (* TODO when rewriting to Ocaml 5.x, the "else" case may result in a
       concurrency bug, though it's safe in single-threaded ocaml execution.

       Recommendation: have alternative to [fill_if_empty] that doesn't
       that returns a boolean with whether the fill was successful.
    *)
    let short_lived_pipe = Short_lived_pipe (Ivar.create ()) in
    let processed_signal = Ivar.create () in
    Ivar.fill t.next_short_lived_pipe (short_lived_pipe, processed_signal) ;
    let%map () = Ivar.read processed_signal in
    short_lived_pipe

let kill (Swappable t) = Ivar.fill_if_empty t.termination_signal ()
