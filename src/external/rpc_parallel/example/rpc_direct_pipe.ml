open Core
open Async

module Sum_worker = struct
  module T = struct
    type 'worker functions =
      { sum : ('worker, int, string) Rpc_parallel.Function.Direct_pipe.t }

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

      let sum_impl ~worker_state:() ~conn_state:() arg writer =
        let _sum =
          List.fold
            ~init:0
            ~f:(fun acc x ->
              let acc = acc + x in
              let output = sprintf "Sum_worker.sum: %i\n" acc in
              let _ = Rpc.Pipe_rpc.Direct_stream_writer.write writer output in
              acc)
            (List.init arg ~f:Fn.id)
        in
        Rpc.Pipe_rpc.Direct_stream_writer.close writer;
        Deferred.unit

      let sum =
        C.create_direct_pipe ~f:sum_impl ~bin_input:Int.bin_t ~bin_output:String.bin_t ()

      let functions = { sum }

      let init_worker_state () = return ()

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
  Sum_worker.spawn
    ~on_failure:Error.raise
    ?cd:log_dir
    ~shutdown_on:Disconnect
    ~redirect_stdout
    ~redirect_stderr
    ~connection_state_init_arg:()
    ()
  >>=? fun conn ->
  let on_write = function
    | Rpc.Pipe_rpc.Pipe_message.Closed _ -> Rpc.Pipe_rpc.Pipe_response.Continue
    | Update s ->
      Core.print_string s;
      Rpc.Pipe_rpc.Pipe_response.Continue
  in
  Sum_worker.Connection.run conn ~f:Sum_worker.functions.sum ~arg:(max, on_write)
  >>|? fun _ -> ()

let command =
  Command.async_spec_or_error ~summary:"Simple use of Async Rpc_parallel V2"
    Command.Spec.(
      empty
      +> flag "max" (required int) ~doc:""
      +> flag "log-dir" (optional string)
           ~doc:" Folder to write worker logs to"
    )
    main

let () = Rpc_parallel.start_app command
