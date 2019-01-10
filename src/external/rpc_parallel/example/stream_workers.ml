open Core
open Async

(* This example involves a [Stream_worker.t] that generates a stream of elements.
   Each element of the stream is sent to a random [Worker.t] that has registered itself
   with that stream. Each [Worker.t] processes the elements (in this example by sending it
   back to the main process for printing) *)

module Stream_worker = struct
  module T = struct
    type 'worker functions =
      { subscribe : ('worker, unit, int Pipe.Reader.t) Rpc_parallel.Function.t
      ; start : ('worker, unit, unit) Rpc_parallel.Function.t }

    module Worker_state = struct
      type init_arg = int [@@deriving bin_io]
      type t =
        { num_elts : int
        ; mutable workers : int Pipe.Writer.t list }
    end

    module Connection_state = struct
      type init_arg = unit [@@deriving bin_io]
      type t = unit
    end

    module Functions (C : Rpc_parallel.Creator
                      with type connection_state := unit
                       and type worker_state := Worker_state.t) = struct

      let init_connection_state ~connection:_ ~worker_state:_ = return

      let init_worker_state num_elts =
        return
          { Worker_state.num_elts
          ; workers = []
          }

      let subscribe_impl ~worker_state ~conn_state:() () =
        let r, w = Pipe.create () in
        (Pipe.closed w
         >>> fun () ->
         worker_state.Worker_state.workers <-
           List.filter worker_state.Worker_state.workers ~f:(fun worker ->
             not (Pipe.equal worker w)));
        worker_state.Worker_state.workers <- w :: worker_state.Worker_state.workers;
        return r

      let start_impl ~worker_state ~conn_state:() () =
        let next_elt = ref 0 in
        let get_element () =
          let elt = !next_elt in
          incr next_elt;
          elt
        in
        don't_wait_for
          (Deferred.repeat_until_finished worker_state.Worker_state.num_elts (fun count ->
             Clock.after (sec 0.05) >>= fun () ->
             if count = 0 then
               return (`Finished ())
             else
               let elt = get_element () in
               let to_worker =
                 List.nth_exn worker_state.workers
                   (Random.int (List.length worker_state.workers))
               in
               Pipe.write to_worker elt
               >>| fun () -> `Repeat (count -1))
           >>| fun () ->
           List.iter worker_state.workers
             ~f:(fun writer -> Pipe.close writer));
        return ()

      let subscribe =
        C.create_pipe ~f:subscribe_impl
          ~bin_input:Unit.bin_t ~bin_output:Int.bin_t ()

      let start =
        C.create_rpc ~f:start_impl
          ~bin_input:Unit.bin_t ~bin_output:Unit.bin_t ()

      let functions = { start; subscribe }
    end
  end
  include Rpc_parallel.Make (T)
end

module Worker = struct
  module T = struct
    type 'worker functions =
      { process_elts : ('worker, Stream_worker.t, int Pipe.Reader.t) Rpc_parallel.Function.t }

    module Worker_state = struct
      type t = unit
      type init_arg = unit [@@deriving bin_io]
    end

    module Connection_state = struct
      type init_arg = unit [@@deriving bin_io]
      type t = unit
    end

    module Functions
        (C : Rpc_parallel.Creator
         with type worker_state := Worker_state.t
          and type connection_state := Connection_state.t) = struct

      let process_elts_impl ~worker_state:() ~conn_state:() stream_worker =
        let check_r, check_w = Pipe.create () in
        Stream_worker.Connection.client_exn stream_worker ()
        >>= fun conn ->
        Stream_worker.Connection.run_exn conn ~f:Stream_worker.functions.subscribe ~arg:()
        >>= fun reader ->
        (Pipe.iter reader ~f:(fun i -> Pipe.write check_w i)
         >>> fun () ->
         Pipe.close check_w);
        return check_r

      let process_elts =
        C.create_pipe ~f:process_elts_impl
          ~bin_input:Stream_worker.bin_t ~bin_output:Int.bin_t ()

      let functions = { process_elts }

      let init_worker_state () = Deferred.unit

      let init_connection_state ~connection:_ ~worker_state:_ = return
    end

  end
  include Rpc_parallel.Make (T)
end

let handle_error worker err =
  failwiths (sprintf "error in %s" worker) err Error.sexp_of_t

let command =
  Command.async_spec_or_error ~summary:"foo"
    Command.Spec.(
      empty
      +> flag "-num-workers" (optional_with_default 4 int)
           ~doc:" number of workers"
      +> flag "-num-elts" (optional_with_default 50 int)
           ~doc:" number of elements to process"
    )
    (fun num_workers num_elements () ->
       (* Spawn a stream worker *)
       Stream_worker.spawn
         ~shutdown_on:Heartbeater_timeout
         ~redirect_stdout:`Dev_null
         ~redirect_stderr:`Dev_null
         num_elements
         ~on_failure:(handle_error "stream worker")
       >>=? fun stream_worker ->
       (* Spawn workers and tell them about the stream worker  *)
       Deferred.Or_error.List.init num_workers ~f:(fun i ->
         Worker.spawn
           ~shutdown_on:Disconnect
           ~connection_state_init_arg:()
           ~redirect_stdout:`Dev_null
           ~redirect_stderr:`Dev_null
           ()
           ~on_failure:(handle_error (sprintf "worker %d" i))
         >>=? fun worker_conn ->
         Worker.Connection.run worker_conn
           ~f:Worker.functions.process_elts ~arg:stream_worker)
       >>=? fun workers ->
       (* Start the stream *)
       Stream_worker.Connection.client stream_worker ()
       >>=? fun stream_conn ->
       Stream_worker.Connection.run stream_conn ~f:Stream_worker.functions.start ~arg:()
       >>=? fun () ->
       (* Collect the results *)
       let elements = List.init num_elements ~f:(fun _i -> Ivar.create ()) in
       don't_wait_for (Deferred.List.iter ~how:`Parallel workers ~f:(fun worker ->
         Pipe.iter worker ~f:(fun num -> Ivar.fill (List.nth_exn elements num) () |> return)));
       Deferred.all_unit (List.map elements ~f:Ivar.read)
       >>| fun () ->
       printf "Ok.\n";
       Or_error.return ())

let () = Rpc_parallel.start_app command
