open Async_kernel
open Core_kernel

type 'data_in_pipe t =
  [ `Eof | `Ok of 'data_in_pipe * 'data_in_pipe t ] Ivar.t Ivar.t

let close (outer_ivar : _ t) =
  Ivar.fill_if_empty outer_ivar (Ivar.create_full `Eof) ;
  Option.iter (Ivar.peek outer_ivar) ~f:(Fn.flip Ivar.fill_if_empty `Eof)

let create () = Ivar.create ()

let create_closed () = Ivar.create_full (Ivar.create_full `Eof)

let write_choice ~on_chosen sink data =
  choice (Ivar.read sink) (fun ivar ->
      let new_sink = Ivar.create () in
      (* We use [Ivar.fill_if_empty] because [close] operation
         may have been invoked and [`Eof] might already be written
         to the ivar. *)
      Ivar.fill_if_empty ivar (`Ok (data, new_sink)) ;
      on_chosen new_sink )

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
