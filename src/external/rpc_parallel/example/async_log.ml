open Core
open Async

module Worker = struct
  module T = struct
    type 'worker functions =
      { write_to_log_global : ('worker, unit, unit) Rpc_parallel.Function.t }

    module Worker_state = struct
      type init_arg = unit [@@deriving bin_io]
      type t = unit
    end

    module Connection_state = struct
      type init_arg = unit [@@deriving bin_io]
      type t = unit
    end

    module Functions (C : Rpc_parallel.Creator) = struct
      let write_to_log_global =
        C.create_rpc ~bin_input:Unit.bin_t ~bin_output:Unit.bin_t
          ~f:(fun ~worker_state:_ ~conn_state:_ () ->
            Log.Global.info "worker log message";
            Log.Global.flushed ())
          ()
      ;;

      let functions = { write_to_log_global }

      let init_worker_state () = Deferred.unit
      ;;

      let init_connection_state ~connection:_ ~worker_state:_ = return
    end
  end
  include Rpc_parallel.Make(T)
end

let expect_log_entry readers =
  Deferred.List.iter readers ~f:(fun reader ->
    match%map Pipe.read reader with
    | `Eof -> failwith "Unexpected EOF"
    | `Ok entry ->
      printf !"%{sexp:Log.Message.Stable.V2.t}\n" entry)
;;

let main () =
  let%bind worker =
    Worker.spawn_exn ~on_failure:Error.raise
      ~shutdown_on:Heartbeater_timeout
      ~redirect_stdout:`Dev_null ~redirect_stderr:`Dev_null ()
  in
  let%bind conn = Worker.Connection.client_exn worker () in
  let get_log_reader () =
    Worker.Connection.run_exn conn ~f:Rpc_parallel.Function.async_log ~arg:()
  in
  let worker_write_to_log_global () =
    Worker.Connection.run_exn conn ~f:Worker.functions.write_to_log_global ~arg:()
  in
  let%bind log_reader1 = get_log_reader () in
  let%bind log_reader2 = get_log_reader () in
  let%bind () = worker_write_to_log_global () in
  let%bind () = expect_log_entry [log_reader1; log_reader2] in
  Pipe.close_read log_reader1;
  let%bind () = worker_write_to_log_global () in
  expect_log_entry [log_reader2]
;;

let command =
  Command.async ~summary:"Using the built in log redirection function"
    (Command.Param.return main)
;;

let () = Rpc_parallel.start_app command
