open Core
open Async


(* This demonstrates how to take advantage of the feature in the [Rpc_parallel]
   library that a [Worker.t] type is defined [with bin_io]. *)

module Worker = struct
  module T = struct
    (* A [Worker.t] implements two functions: [ping : unit -> int] and
       [dispatch : Worker.t -> int] *)
    type 'worker functions =
      { ping:('worker, unit, int) Rpc_parallel.Function.t }

    (* Internal state for each [Worker.t]. Every [Worker.t] has a counter that gets
       incremented anytime it gets pinged *)
    module Worker_state = struct
      type init_arg = unit [@@deriving bin_io]
      type t = int ref
    end

    module Connection_state = struct
      type init_arg = unit [@@deriving bin_io]
      type t = unit
    end

    module Functions
        (C : Rpc_parallel.Creator
         with type worker_state := Worker_state.t
          and type connection_state := Connection_state.t) = struct
      (* When a worker gets a [ping ()] call, increment its counter and return the current
         value *)
      let ping_impl ~worker_state:counter ~conn_state:() () =
        incr counter; return (!counter)

      let ping = C.create_rpc ~f:ping_impl ~bin_input:Unit.bin_t ~bin_output:Int.bin_t ()

      let functions = {ping}

      let init_worker_state () = return (ref 0)

      let init_connection_state ~connection:_ ~worker_state:_ = return
    end
  end
  include Rpc_parallel.Make (T)
end

module Dispatcher = struct
  module T = struct
    type 'worker functions =
      { dispatch: ('worker, Worker.t, int) Rpc_parallel.Function.t }

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
      (* When a worker gets a [dispatch worker] call, call [ping] on the supplied worker
         and return the same result. *)
      let dispatch_impl ~worker_state:_ ~conn_state:() worker =
        Worker.Connection.with_client worker () ~f:(fun conn ->
          Worker.Connection.run_exn conn ~f:Worker.functions.ping ~arg:())
        >>| Or_error.ok_exn

      let dispatch =
        C.create_rpc ~f:dispatch_impl ~bin_input:Worker.bin_t ~bin_output:Int.bin_t ()

      let functions = {dispatch}

      let init_worker_state () = Deferred.unit

      let init_connection_state ~connection:_ ~worker_state:_ = return

    end

  end
  include Rpc_parallel.Make (T)
end

let command =
  Command.async_spec_or_error ~summary:
    "Example of a worker taking in another worker as an argument to one of its functions"
    Command.Spec.(
      empty
    )
    (fun () ->
       Worker.spawn
         ~shutdown_on:Heartbeater_timeout
         ~redirect_stdout:`Dev_null
         ~redirect_stderr:`Dev_null
         ~on_failure:Error.raise
         ()
       >>=? fun worker ->
       Worker.Connection.client worker ()
       >>=? fun worker_conn ->
       Dispatcher.spawn
         ~shutdown_on:Disconnect
         ~redirect_stdout:`Dev_null
         ~redirect_stderr:`Dev_null
         ~on_failure:Error.raise
         ~connection_state_init_arg:()
         ()
       >>=? fun dispatcher_conn ->
       let repeat job n =
         Deferred.List.iter (List.range 0 n) ~f:(fun _i -> job ())
       in
       Deferred.all_unit [
         repeat (fun () ->
           Dispatcher.Connection.run_exn dispatcher_conn ~f:Dispatcher.functions.dispatch
             ~arg:worker
           >>= fun count ->
           Core.Printf.printf "worker pinged from dispatcher: %d\n%!" count;
           return ()) 10;
         repeat (fun () ->
           Worker.Connection.run_exn worker_conn ~f:Worker.functions.ping
             ~arg:()
           >>= fun count ->
           Core.Printf.printf "worker pinged from master: %d\n%!" count;
           return ()) 10
       ] >>= fun () -> Deferred.Or_error.ok_unit)

let () = Rpc_parallel.start_app command
