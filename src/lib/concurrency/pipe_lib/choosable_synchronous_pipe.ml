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

let close (outer_ivar : _ t) =
  Ivar.fill_if_empty outer_ivar (Ivar.create_full `Eof) ;
  Option.iter (Ivar.peek outer_ivar) ~f:(Fn.flip Ivar.fill_if_empty `Eof)

let create () =
  let pipe = Ivar.create () in
  (pipe, pipe)

let create_closed () = Ivar.create_full (Ivar.create_full `Eof)

let write_choice ~on_chosen sink data =
  choice (Ivar.read sink) (fun ivar ->
      let new_sink = Ivar.create () in
      (* We use [Ivar.fill_if_empty] because [close] operation
         may have been invoked and [`Eof] might already be written
         to the ivar. *)
      Ivar.fill_if_empty ivar (`Ok (data, new_sink)) ;
      on_chosen new_sink )

let write sink data =
  (* Implementation copies [write_choice] *)
  let%map ivar = Ivar.read sink in
  let new_sink = Ivar.create () in
  Ivar.fill_if_empty ivar (`Ok (data, new_sink)) ;
  new_sink

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
