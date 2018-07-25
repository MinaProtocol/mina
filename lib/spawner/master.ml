open Core
open Async
open Linear_pipe

module type S = sig
  type t

  type state

  type id

  type input

  type server_config

  val create : unit -> t

  val add : t -> input -> id -> config:server_config -> unit Deferred.t

  val run : t -> id -> unit Deferred.t option

  val new_states : t -> (id * state) Linear_pipe.Reader.t
end

module Make
    (Worker : Parallel_worker.Parallel_worker_intf)
    (Id : Hashable.S_binable) :
  S
  with type state := Worker.state
   and type input := Worker.input
   and type server_config := Worker.config
   and type id := Id.t =
struct
  type t =
    { workers: Worker.t Id.Table.t
    ; read_new_states: (Id.t * Worker.state) Linear_pipe.Reader.t
    ; write_new_states: (Id.t * Worker.state) Linear_pipe.Writer.t }

  let new_states {read_new_states} = read_new_states

  let create () =
    Parallel.init_master () ;
    let table = Id.Table.create () in
    let read_new_states, write_new_states = Linear_pipe.create () in
    {workers= table; read_new_states; write_new_states}

  let add {workers; write_new_states} query id ~config =
    let%bind worker = Worker.create query config in
    Id.Table.set workers ~key:id ~data:worker ;
    let%map state_pipe = Worker.new_states worker in
    don't_wait_for
    @@ Pipe.iter state_pipe ~f:(fun state ->
           Linear_pipe.write write_new_states (id, state) )

  let run {workers} id = Option.map ~f:Worker.run @@ Id.Table.find workers id
end
