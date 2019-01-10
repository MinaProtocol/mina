open Core
open Async

(* A bare bones use case of the [Rpc_parallel] library. This demonstrates how to
   define a simple worker type that implements some functions. The master then spawns a
   worker of this type and calls a function to run on this worker *)

module Sum_worker = struct
  module T = struct
    (* A [Sum_worker.worker] implements a single function [sum : int -> int]. Because this
       function is parameterized on a ['worker], it can only be run on workers of the
       [Sum_worker.worker] type. *)
    type 'worker functions = {sum:('worker, int, int) Rpc_parallel.Function.t}

    (* No initialization upon spawn *)
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
      (* Define the implementation for the [sum] function *)
      let sum_impl ~worker_state:() ~conn_state:() arg =
        let sum = List.fold ~init:0 ~f:(+) (List.init arg ~f:Fn.id) in
        Log.Global.info "Sum_worker.sum: %i\n" sum;
        return sum

      (* Create a [Rpc_parallel.Function.t] from the above implementation *)
      let sum = C.create_rpc ~f:sum_impl ~bin_input:Int.bin_t ~bin_output:Int.bin_t ()

      (* This type must match the ['worker functions] type defined above *)
      let functions = {sum}

      let init_worker_state () = Deferred.unit

      let init_connection_state ~connection:_ ~worker_state:_ = return
    end
  end
  include Rpc_parallel.Make(T)
end

let main max log_dir () =
  let redirect_stdout, redirect_stderr =
    match log_dir with
    | None -> (`Dev_null, `Dev_null)
    | Some _ -> (`File_append "sum.out", `File_append "sum.err")
  in
  (* This is the main function called in the master. Spawn a local worker and run
     the [sum] function on this worker *)
  Sum_worker.spawn
    ~on_failure:Error.raise
    ?cd:log_dir
    ~shutdown_on:Disconnect
    ~redirect_stdout
    ~redirect_stderr
    ~connection_state_init_arg:()
    ()
  >>=? fun conn ->
  Sum_worker.Connection.run conn ~f:Sum_worker.functions.sum ~arg:max
  >>=? fun res ->
  Core.Printf.printf "sum_worker: %d\n%!" res;
  Deferred.Or_error.ok_unit

let command =
  (* Make sure to always use [Command.async] *)
  Command.async_spec_or_error ~summary:"Simple use of Async Rpc_parallel V2"
    Command.Spec.(
      empty
      +> flag "max" (required int) ~doc:""
      +> flag "log-dir" (optional string)
           ~doc:" Folder to write worker logs to"
    )
    main

(* This call to [Rpc_parallel.start_app] must be top level *)
let () = Rpc_parallel.start_app command
