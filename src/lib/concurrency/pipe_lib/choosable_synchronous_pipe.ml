open Async_kernel
open Core_kernel

(** The same type is used to represent both reader and writer.
    
   A single [val : 'data_in_pipe t] is created and returned as both reader and
   writer. However as writing and reading progress, subsequent values returned
   from [read] and [write_choice] will be different.
*)
type 'data_in_pipe t =
  [ `Eof | `Ok of 'data_in_pipe * 'data_in_pipe t ] Ivar.t Ivar.t

type 'data_in_pipe writer_t = 'data_in_pipe t

type 'data_in_pipe reader_t = 'data_in_pipe t

exception Pipe_closed

exception Pipe_handle_used

let fill_inner_ivar inner_ivar value =
  try Ivar.fill inner_ivar value
  with _ -> (
    match Ivar.value_exn inner_ivar with
    | `Eof ->
        raise Pipe_closed
    | `Ok _ ->
        raise Pipe_handle_used )

let close (outer_ivar : _ t) =
  Ivar.fill_if_empty outer_ivar (Ivar.create ()) ;
  let inner_ivar = Ivar.value_exn outer_ivar in
  fill_inner_ivar inner_ivar `Eof

let create () =
  let pipe = Ivar.create () in
  (pipe, pipe)

let create_closed () = Ivar.create_full (Ivar.create_full `Eof)

let on_write_chosen ~on_chosen ~data ivar =
  let new_sink = Ivar.create () in
  fill_inner_ivar ivar (`Ok (data, new_sink)) ;
  on_chosen new_sink

let write_choice ~on_chosen sink data =
  choice (Ivar.read sink) (on_write_chosen ~on_chosen ~data)

let write sink data = Ivar.read sink >>| on_write_chosen ~on_chosen:Fn.id ~data

let read (outer_ivar : _ t) =
  Ivar.fill_if_empty outer_ivar (Ivar.create ()) ;
  Ivar.read (Ivar.value_exn outer_ivar)

let iter (t_initial : _ t) ~f =
  Deferred.repeat_until_finished t_initial (fun t ->
      match%bind read t with
      | `Eof ->
          Deferred.return (`Finished ())
      | `Ok (data, t') ->
          f data >>| fun () -> `Repeat t' )
