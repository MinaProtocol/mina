open Core
open Async

module Worker = struct
  module T = struct
    type 'worker functions = {print:('worker, string, unit) Rpc_parallel.Function.t}

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
      let print_impl ~worker_state:() ~conn_state:() string =
        printf "%s\n" string;
        return ()

      let print = C.create_rpc ~f:print_impl ~bin_input:String.bin_t ~bin_output:Unit.bin_t ()

      let functions = {print}

      let init_worker_state () = Deferred.unit

      let init_connection_state ~connection:_ ~worker_state:_ = return
    end
  end
  include Rpc_parallel.Make(T)
end

let main () =
  Worker.spawn_in_foreground ~shutdown_on:Disconnect ~connection_state_init_arg:()
    ~on_failure:Error.raise ()
  >>=? fun (conn, process) ->
  Worker.Connection.run conn ~f:Worker.functions.print ~arg:"HELLO"
  >>=? fun () ->
  Worker.Connection.run conn ~f:Worker.functions.print ~arg:"HELLO2"
  >>=? fun () ->
  Worker.Connection.close conn
  >>= fun () ->
  Process.wait process
  >>= fun (_ : Unix.Exit_or_signal.t) ->
  let worker_stderr = Reader.lines (Process.stderr process) in
  let worker_stdout = Reader.lines (Process.stdout process) in
  Pipe.iter worker_stderr ~f:(fun line ->
    let line' = sprintf "[WORKER STDERR]: %s\n" line in
    Writer.write (Lazy.force Writer.stdout) line' |> return)
  >>= fun () ->
  Pipe.iter worker_stdout ~f:(fun line ->
    let line' = sprintf "[WORKER STDOUT]: %s\n" line in
    Writer.write (Lazy.force Writer.stdout) line' |> return)
  >>= fun () ->
  Deferred.Or_error.ok_unit

let command =
  Command.async_spec_or_error ~summary:"Example of spawn_in_foreground"
    Command.Spec.empty
    main

let () = Rpc_parallel.start_app command
