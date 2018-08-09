open Core
open Async
open Linear_pipe

module type Worker_intf = sig
  type t

  type input [@@deriving bin_io]

  type state [@@deriving bin_io]

  val create : input -> t Deferred.t

  val new_states : t -> state Pipe.Reader.t

  val run : t -> unit Deferred.t
end

module type Parallel_worker_intf = sig
  type t

  type input

  type state

  type config

  val create : input -> config -> t Deferred.t

  val new_states : t -> state Pipe.Reader.t Deferred.t

  val run : t -> unit Deferred.t
end

module type Id_intf = sig
  type t

  val to_string : t -> string
end

module Make (Worker : Worker_intf) (Id : Id_intf) :
  Parallel_worker_intf
  with type input = Worker.input
   and type state = Worker.state
   and type config = (Id.t, string, string) Config.t =
struct
  type input = Worker.input

  type state = Worker.state

  type config = (Id.t, string, string) Config.t

  module Rpc_worker = struct
    module T = struct
      type 'worker functions =
        { new_states:
            ('worker, unit, Worker.state Pipe.Reader.t) Rpc_parallel.Function.t
        ; run: ('worker, unit, unit) Rpc_parallel.Function.t }

      module Worker_state = struct
        type init_arg = Worker.input [@@deriving bin_io]

        type t = Worker.t
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
        let new_states =
          C.create_pipe ~bin_input:Unit.bin_t ~bin_output:Worker.bin_state ()
            ~f:(fun ~worker_state ~conn_state () ->
              return @@ Worker.new_states worker_state )

        let run =
          C.create_rpc ~bin_input:Unit.bin_t ~bin_output:Unit.bin_t () ~f:
            (fun ~worker_state ~conn_state () -> Worker.run worker_state )

        let functions = {new_states; run}

        let init_worker_state = Worker.create

        let init_connection_state ~connection:_ ~worker_state:_ = return
      end
    end

    include Rpc_parallel.Make (T)
  end

  type t = Rpc_worker.Connection.t

  let create input {Config.id; host; executable_path} =
    let worker_id = sprintf "worker-%s-%s" host (Id.to_string id)
    and worker_location =
      if host = Command_util.local_machine_host then
        Rpc_parallel.Executable_location.Local
      else
        Rpc_parallel.Executable_location.Remote
          (Rpc_parallel.Remote_executable.existing_on_host ~executable_path
             ~strict_host_key_checking:`No host)
    in
    match%bind
      Rpc_worker.spawn_in_foreground input ~on_failure:Error.raise
        ~shutdown_on:Disconnect ~connection_state_init_arg:()
        ~connection_timeout:(Time.Span.of_sec 15.) ~name:worker_id
        ~where:worker_location
    with
    | Ok (worker, process) ->
        let print_worker_message = Core.sprintf !"(%s %s)%!" worker_id in
        File_system.dup_stdout ~f:print_worker_message process ;
        File_system.dup_stderr ~f:print_worker_message process ;
        return worker
    | Error e ->
        failwith
          (sprintf "Could not create %s\n%s\n" worker_id
             (Error.to_string_hum e))

  let execute_command t input ~f =
    Rpc_worker.Connection.run_exn t ~f ~arg:input

  let run t = execute_command t () ~f:Rpc_worker.functions.run

  let new_states t = execute_command t () ~f:Rpc_worker.functions.new_states
end
