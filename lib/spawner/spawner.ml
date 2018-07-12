open Core
open Async
open Linear_pipe

module type Worker_intf = sig
  type t

  type state

  type input

  val create : input -> t

  val run : t -> unit Deferred.t

  val state_broadcasts : t -> state Pipe.Reader.t Deferred.t
end

module type S = sig
  type t

  type state

  type key

  type input

  val create : unit -> t

  val add : t -> input -> key -> unit

  val run : t -> key -> unit Deferred.t option

  val broadcasts : t -> (key * state) Linear_pipe.Reader.t
end

module Make (Worker : Worker_intf) (Key : Hashable.S_binable) :
  S
  with type state := Worker.state
   and type input := Worker.input
   and type key := Key.t =
struct
  type t =
    { workers: Worker.t Key.Table.t
    ; read_broadcasts: (Key.t * Worker.state) Linear_pipe.Reader.t
    ; write_broadcasts: (Key.t * Worker.state) Linear_pipe.Writer.t }

  let broadcasts {read_broadcasts} = read_broadcasts

  let create () =
    let table = Key.Table.create () in
    let read_broadcasts, write_broadcasts = Linear_pipe.create () in
    {workers= table; read_broadcasts; write_broadcasts}

  let add {workers; write_broadcasts} query key =
    let worker = Worker.create query in
    Key.Table.set workers ~key ~data:worker ;
    don't_wait_for
    @@ let%bind state_pipe = Worker.state_broadcasts worker in
       Pipe.iter state_pipe ~f:(fun state ->
           Linear_pipe.write write_broadcasts (key, state) )

  let run {workers} key =
    Option.map ~f:Worker.run @@ Key.Table.find workers key
end

module Rpc_worker = struct
  module T = struct
    type 'worker functions =
      { get_state: ('worker, unit, int) Rpc_parallel.Function.t
      ; set_state: ('worker, int, unit) Rpc_parallel.Function.t
      ; broadcasts: ('worker, unit, int Pipe.Reader.t) Rpc_parallel.Function.t
      }

    module Worker_state = struct
      type init_arg = {id: int; state: int} [@@deriving bin_io]

      type t =
        { id: int
        ; mutable state: int
        ; reader: int Pipe.Reader.t
        ; writer: int Pipe.Writer.t }

      let get_state (t: t) : int = t.state

      let set_state (t: t) new_state : unit = t.state <- new_state

      let broadcasts ({reader}: t) = reader

      let write ({writer}: t) = writer
    end

    module Connection_state = struct
      type init_arg = unit [@@deriving bin_io]

      type t = unit
    end

    module Functions
        (C : Rpc_parallel.Creator
             with type worker_state := Worker_state.t
              and type connection_state := Connection_state.t) =
    struct
      let get_state =
        C.create_rpc ~bin_input:Unit.bin_t ~bin_output:Int.bin_t () ~f:
          (fun ~worker_state ~conn_state () ->
            return @@ Worker_state.get_state worker_state )

      let set_state =
        C.create_rpc ~bin_input:Int.bin_t ~bin_output:Unit.bin_t () ~f:
          (fun ~worker_state ~conn_state new_state ->
            let writer_pipe = Worker_state.write worker_state in
            let%map () = Pipe.write writer_pipe new_state in
            Worker_state.set_state worker_state new_state )

      let broadcasts =
        C.create_pipe ~bin_input:Unit.bin_t ~bin_output:Int.bin_t () ~f:
          (fun ~worker_state ~conn_state () ->
            return @@ Worker_state.broadcasts worker_state )

      let functions = {get_state; set_state; broadcasts}

      let init_worker_state ({id; state}: Worker_state.init_arg) :
          Worker_state.t Deferred.t =
        let reader, writer = Pipe.create () in
        return @@ {Worker_state.id; state; reader; writer}

      let init_connection_state ~connection:_ ~worker_state:_ = return
    end
  end

  include Rpc_parallel.Make (T)
end

module Worker = struct
  type t = Rpc_worker.Connection.t Deferred.t

  type state = int

  type input = Rpc_worker.T.Worker_state.init_arg

  let create ({id; state}: Rpc_worker.T.Worker_state.init_arg) =
    let%bind worker =
      Rpc_worker.spawn_exn ~on_failure:Error.raise
        ~shutdown_on:Heartbeater_timeout ~redirect_stdout:`Dev_null
        ~redirect_stderr:`Dev_null ~name:(sprintf "Server %d" id) {id; state}
    in
    Rpc_worker.Connection.client_exn worker ()

  let execute_command ~connection input ~f =
    Rpc_worker.Connection.run_exn connection ~f ~arg:input

  let set_state = execute_command ~f:Rpc_worker.functions.set_state

  let get_state = execute_command () ~f:Rpc_worker.functions.get_state

  let state_broadcasts deferred_t =
    let%bind t = deferred_t in
    execute_command () ~f:Rpc_worker.functions.broadcasts ~connection:t

  let run deferred_t =
    let%bind t = deferred_t in
    let%bind state = get_state t in
    set_state t (2 * state)
end

module Rpc_master = Make (Worker) (Int)

let run () =
  let open Deferred.Let_syntax in
  let open Rpc_master in
  let t = create () in
  let add_worker (input: Worker.input) = add t input input.id in
  add_worker {id= 1; state= 1} ;
  add_worker {id= 2; state= 2} ;
  let%bind () = Option.value_exn (run t 1) in
  let reader = broadcasts t in
  let expected_state = 2 in
  match%map Linear_pipe.read reader with
  | `Eof -> failwith "Expecting a value from reader"
  | `Ok (_, state) -> assert (expected_state = state)

let command =
  Command.async ~summary:"Demo of coordinator" (Command.Param.return run)

let () = Rpc_parallel.start_app command
