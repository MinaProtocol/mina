open Core
open Async

(* An example demonstrating how workers can themselves act as masters and spawn more
   workers. We have two layers of workers, where the first layer spawns the workers of the
   second layer. *)

module Secondary_worker = struct
  module T = struct
    type 'worker functions =
      { ping:('worker, unit, string) Rpc_parallel.Function.t
      }

    module Worker_state = struct
      type init_arg = unit [@@deriving bin_io]
      type t = unit
    end

    module Connection_state = struct
      type init_arg = unit [@@deriving bin_io]
      type t = unit
    end

    module Functions
        (C : Rpc_parallel.Creator
         with type worker_state := Worker_state.t
          and type connection_state := Connection_state.t) = struct
      let ping_impl ~worker_state:() ~conn_state:() () = return "pong"

      let ping =
        C.create_rpc ~f:ping_impl ~bin_input:Unit.bin_t ~bin_output:String.bin_t ()

      let functions = {ping}

      let init_worker_state () = Deferred.unit

      let init_connection_state ~connection:_ ~worker_state:_ = return
    end
  end
  include Rpc_parallel.Make (T)
end

module Primary_worker = struct
  module T = struct
    type ping_result = string list [@@deriving bin_io]
    type 'worker functions =
      { run:('worker, int, unit) Rpc_parallel.Function.t
      ; ping:('worker, unit, ping_result) Rpc_parallel.Function.t
      }

    let workers = Bag.create ()
    let next_worker_name () = sprintf "Secondary worker #%i" (Bag.length workers)

    module Worker_state = struct
      type init_arg = unit [@@deriving bin_io]
      type t = unit
    end

    module Connection_state = struct
      type init_arg = unit [@@deriving bin_io]
      type t = unit
    end

    module Functions
        (C : Rpc_parallel.Creator
         with type worker_state := Worker_state.t
          and type connection_state := Connection_state.t) = struct
      let run_impl ~worker_state:() ~conn_state:() num_workers =
        Deferred.List.init ~how:`Parallel num_workers ~f:(fun _i ->
          Secondary_worker.spawn_exn
            ~shutdown_on:Heartbeater_timeout
            ~redirect_stdout:`Dev_null ~redirect_stderr:`Dev_null
            ~on_failure:Error.raise ()
          >>| fun secondary_worker ->
          ignore(Bag.add workers (next_worker_name (), secondary_worker));
        )
        >>| ignore

      let run = C.create_rpc ~f:run_impl ~bin_input:Int.bin_t ~bin_output:Unit.bin_t ()

      let ping_impl ~worker_state:() ~conn_state:() () =
        Deferred.List.map ~how:`Parallel (Bag.to_list workers) ~f:(fun (name, worker) ->
          Secondary_worker.Connection.client worker ()
          >>= function
          | Error e -> failwiths "failed connecting to worker" e [%sexp_of: Error.t]
          | Ok conn ->
            Secondary_worker.Connection.run conn ~arg:() ~f:Secondary_worker.functions.ping
            >>| function
            | Error e ->
              sprintf "%s: failed (%s)" name (Error.to_string_hum e)
            | Ok s -> sprintf "%s: %s" name s
        )

      let ping =
        C.create_rpc ~f:ping_impl ~bin_input:Unit.bin_t ~bin_output:bin_ping_result ()

      let functions = {run; ping}

      let init_worker_state () =
        Bag.clear workers;
        Deferred.unit

      let init_connection_state ~connection:_ ~worker_state:_ = return
    end
  end
  include Rpc_parallel.Make(T)
end

let command =
  (* Make sure to always use [Command.async] *)
  Command.async_spec_or_error ~summary:"Simple use of Async Rpc_parallel V2"
    Command.Spec.(
      empty
      +> flag "primary" (required int)
           ~doc:" Number of primary workers to spawn"
      +> flag "secondary" (required int)
           ~doc:" Number of secondary workers each primary worker should spawn"
    )
    (fun primary secondary () ->
       Deferred.Or_error.List.init ~how:`Parallel primary ~f:(fun worker_id ->
         Primary_worker.spawn
           ~shutdown_on:Disconnect
           ~redirect_stdout:`Dev_null ~redirect_stderr:`Dev_null
           ~on_failure:Error.raise
           ~connection_state_init_arg:()
           ()
         >>=? fun conn ->
         Primary_worker.Connection.run conn
           ~f:Primary_worker.functions.run ~arg:secondary
         >>=? fun () ->
         Primary_worker.Connection.run conn
           ~f:Primary_worker.functions.ping ~arg:()
         >>|? fun ping_results ->
         List.map ping_results ~f:(fun s -> sprintf "Primary worker #%i: %s" worker_id s))
       >>|? fun l ->
       List.iter (List.join l) ~f:(printf "%s\n%!")
    )

(* This call to [Rpc_parallel.start_app] must be top level *)
let () = Rpc_parallel.start_app command
