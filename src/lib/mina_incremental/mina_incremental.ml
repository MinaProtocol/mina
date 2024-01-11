(** Different functor instantiations of Incremental in the Coda repository
    along with some functions to interface with pipes. Each module
    instantiation of Incremental should represent a connected component of
    dependencies. We have this modue to prevent adding dependencies to
    different functors*)

open Pipe_lib
open Async_kernel

module Make
    (Incremental : Incremental.S) (Name : sig
      val t : string
    end) =
struct
  include Incremental

  let to_pipe observer =
    let reader, writer =
      Strict_pipe.(
        create
          ~name:("Mina_incremental__" ^ Name.t)
          (Buffered (`Capacity 1, `Overflow (Drop_head ignore))))
    in
    Observer.on_update_exn observer ~f:(function
      | Initialized value ->
          Strict_pipe.Writer.write writer value
      | Changed (_, value) ->
          Strict_pipe.Writer.write writer value
      | Invalidated ->
          () ) ;
    (Strict_pipe.Reader.to_linear_pipe reader).Linear_pipe.Reader.pipe

  let of_broadcast_pipe pipe =
    let init = Broadcast_pipe.Reader.peek pipe in
    let var = Var.create init in
    Broadcast_pipe.Reader.iter pipe ~f:(fun value ->
        Var.set var value ; stabilize () ; Deferred.unit )
    |> don't_wait_for ;
    var

  let of_deferred (deferred : unit Deferred.t) =
    let var = Var.create `Empty in
    don't_wait_for
      (Deferred.map deferred ~f:(fun () ->
           Var.set var `Filled ;
           stabilize () ) ) ;
    var

  let of_ivar (ivar : unit Ivar.t) = of_deferred (Ivar.read ivar)
end

module New_transition =
  Make
    (Incremental.Make
       ())
       (struct
         let t = "New_transition"
       end)

module Status =
  Make
    (Incremental.Make
       ())
       (struct
         let t = "Status"
       end)
