open Core
open Async
open Linear_pipe

module type Worker_intf = sig
  type t

  type input [@@deriving bin_io]

  type state [@@deriving bin_io]

  val create : input -> t

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

module Make (Worker : Worker_intf) :
  Parallel_worker_intf
  with type input = Worker.input
   and type state = Worker.state
   and type config = (string, string, string) Config.t =
struct
  type input = Worker.input

  type state = Worker.state

  type config = (string, string, string) Config.t

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

        let init_worker_state (input: Worker.input) : Worker.t Deferred.t =
          return @@ Worker.create input

        let init_connection_state ~connection:_ ~worker_state:_ = return
      end
    end

    include Rpc_parallel.Make (T)
  end

  type t = Rpc_worker.Connection.t

  let create input {Config.host; executable_path; log_dir} =
    let worker_id = "worker-" ^ host in
    let%bind worker =
      (* TODO: This will not work on an host other than 127.0.0.1. Trying to find a configuration setup (via Docker) to do this *)
      Rpc_worker.spawn_exn input ~on_failure:Error.raise
        ~shutdown_on:Heartbeater_timeout
        ~redirect_stdout:(`File_append (log_dir ^/ worker_id ^ "-stdout"))
        ~redirect_stderr:(`File_append (log_dir ^/ worker_id ^ "-stdout"))
        ~name:worker_id
        ~where:
          (Rpc_parallel.Executable_location.Remote
             (Rpc_parallel.Remote_executable.existing_on_host ~executable_path
                ~strict_host_key_checking:`No host))
    in
    Rpc_worker.Connection.client_exn worker ()

  let execute_command ~connection input ~f =
    Rpc_worker.Connection.run_exn connection ~f ~arg:input

  let run t = execute_command () ~f:Rpc_worker.functions.run ~connection:t

  let new_states t =
    execute_command () ~f:Rpc_worker.functions.new_states ~connection:t
end
