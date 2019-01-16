open Core
open Async

module Worker = struct
  module T = struct
    type 'worker functions = { inc : ('worker, unit, int) Rpc_parallel.Function.t }

    module Worker_state = struct
      type init_arg = int [@@deriving bin_io]
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
      let inc = C.create_rpc
                  ~f:(fun ~worker_state ~conn_state:() () ->
                    incr worker_state; return !worker_state)
                  ~bin_input:Unit.bin_t ~bin_output:Int.bin_t ()

      let functions = {inc}

      let init_worker_state arg = return (ref arg)

      let init_connection_state ~connection:_ ~worker_state:_ = return
    end
  end
  include Rpc_parallel.Make(T)
end

let main () =
  Deferred.List.iter ~how:`Parallel (List.init 10 ~f:Fn.id) ~f:(fun i ->
    Worker.serve i
    >>= fun worker ->
    Worker.Connection.client_exn worker ()
    >>= fun connection1 ->
    Worker.Connection.client_exn worker ()
    >>= fun connection2 ->
    Worker.Connection.run_exn connection1 ~f:Worker.functions.inc ~arg:()
    >>= fun i_plus_one ->
    Worker.Connection.run_exn connection2 ~f:Worker.functions.inc ~arg:()
    >>= fun i_plus_two ->
    assert (i + 1 = i_plus_one);
    assert (i + 2 = i_plus_two);
    Worker.Connection.run_exn connection1 ~f:Rpc_parallel.Function.close_server ~arg:()
    >>= fun () ->
    (* Ensure we can't connect to this server anymore *)
    Worker.Connection.client worker ()
    >>= function
    | Ok _ -> failwith "Should not have been able to connect"
    | Error _ ->
      (* Ensure existing connections still work *)
      Worker.Connection.run_exn connection1 ~f:Worker.functions.inc ~arg:()
      >>| fun i_plus_three ->
      assert (i + 3 = i_plus_three))
  >>| fun () ->
  printf "Success.\n"

let command =
  Command.async_spec ~summary:"Use of the in process [serve] functionality"
    Command.Spec.empty
    main

let () = Rpc_parallel.start_app command
