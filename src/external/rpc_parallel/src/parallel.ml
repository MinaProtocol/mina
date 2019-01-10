open Core
open Async
open Parallel_intf
module Worker_type_id = Utils.Worker_type_id
module Worker_id = Utils.Worker_id

(* All processes start a "master" rpc server. This is a server that has two
   implementations:

   (1) Register - Spawned workers say hello to the spawner
   (2) Handle_exn - Spawned workers send exceptions to the spawner

   Processes can also start "worker" rpc servers (in process using [serve] or out of
   process using [spawn]). A "worker" rpc server has all the user defined implementations
   as well as:

   (1) Init_worker_state - Spawner sends the worker init argument
   (2) Init_connection_state - Connector sends the connection state init argument
   (3) Shutdown, Close_server, Async_log, etc.

   The handshake protocol for spawning a worker:

   (Master) - SSH and start running executable
   (Worker) - Start server, send [Register_rpc] with its host and port
   (Master) - Connect to worker, send [Init_worker_state_rpc]
   (Worker) - Do initialization (ensure we have daemonized first)
   (Master) - Finally, return a [Worker.t] to the caller
*)

module Rpc_settings = struct
  type t =
    { max_message_size: int option
    ; handshake_timeout: Time.Span.t option
    ; heartbeat_config: Rpc.Connection.Heartbeat_config.t option }
  [@@deriving sexp, bin_io]

  let create ~max_message_size ~handshake_timeout ~heartbeat_config =
    {max_message_size; handshake_timeout; heartbeat_config}
end

module Worker_implementations = struct
  type t =
    | T :
        ('state, 'connection_state) Utils.Internal_connection_state.t
        Rpc.Implementation.t
        list
        -> t
end

(* Applications of the [Make()] functor have the side effect of populating an
   [implementations] list which subsequently adds an entry for that worker type id to the
   [worker_implementations]. *)
let worker_implementations = Worker_type_id.Table.create ~size:1 ()

(* All global state that is needed for a process to act as a master *)
type master_state =
  { (* The [Host_and_port.t] corresponding to one's own master Rpc server. *)
    my_server:
      Host_and_port.t Deferred.t lazy_t
      (* The rpc settings used universally for all rpc connections *)
  ; app_rpc_settings:
      Rpc_settings.t
      (* Used to facilitate timeout of connecting to a spawned worker *)
  ; pending:
      Host_and_port.t Ivar.t Worker_id.Table.t
      (* Arguments used when spawning a new worker. *)
  ; worker_command_args:
      [`Decorate_with_name | `User_supplied of string list]
      (* Callbacks for spawned worker exceptions along with the monitor that was current
     when [spawn] was called *)
  ; on_failures: ((Error.t -> unit) * Monitor.t) Worker_id.Table.t }

(* All global state that is not specific to worker types is collected here *)
type worker_state =
  { (* Currently running worker servers in this process *)
    my_worker_servers:
      (Socket.Address.Inet.t, int) Tcp.Server.t Worker_id.Table.t
      (* To facilitate process creation cleanup.*)
  ; initialized:
      [`Init_started of [`Initialized] Or_error.t Deferred.t] Set_once.t }

type global_state = {as_master: master_state; as_worker: worker_state}

(* Each running instance has the capability to work as a master. This state includes
   information needed to spawn new workers (my_server, my_rpc_settings, pending,
   worker_command_args), information to handle existing spawned workerd (on_failures), and
   information to handle worker servers that are running in process. *)
let global_state : global_state Set_once.t = Set_once.create ()

let get_state_exn () =
  match Set_once.get global_state with
  | None -> failwith "State should have been set already"
  | Some state -> state

let get_master_state_exn () = (get_state_exn ()).as_master

let get_worker_state_exn () = (get_state_exn ()).as_worker

(* Functions that are implemented by all workers *)
module Shutdown_rpc = struct
  let rpc =
    Rpc.One_way.create ~name:"shutdown_rpc" ~version:0 ~bin_msg:Unit.bin_t
end

module Close_server_rpc = struct
  let rpc =
    Rpc.One_way.create ~name:"close_server_rpc" ~version:0 ~bin_msg:Unit.bin_t
end

module Async_log_rpc = struct
  let rpc =
    Rpc.Pipe_rpc.create ~name:"async_log_rpc" ~version:0 ~bin_query:Unit.bin_t
      ~bin_response:Log.Message.Stable.V2.bin_t ~bin_error:Error.bin_t ()
end

module Function = struct
  module Rpc_id = Unique_id.Int ()

  let maybe_generate_name ~prefix ~name =
    match name with
    | None -> sprintf "%s_%s" prefix (Rpc_id.to_string (Rpc_id.create ()))
    | Some n -> n

  module Function_piped = struct
    type ('worker, 'query, 'response) t =
      ('query, 'response, Error.t) Rpc.Pipe_rpc.t

    let make_impl ~monitor ~f protocol =
      Rpc.Pipe_rpc.implement protocol
        (fun ((_conn : Rpc.Connection.t), internal_conn_state) arg ->
          let {Utils.Internal_connection_state.conn_state; worker_state; _} =
            Set_once.get_exn internal_conn_state [%here]
          in
          Utils.try_within ~monitor (fun () -> f ~worker_state ~conn_state arg)
      )

    let make_direct_impl ~monitor ~f protocol =
      Rpc.Pipe_rpc.implement_direct protocol
        (fun ((_conn : Rpc.Connection.t), internal_conn_state) arg writer ->
          let {Utils.Internal_connection_state.conn_state; worker_state; _} =
            Set_once.get_exn internal_conn_state [%here]
          in
          Utils.try_within ~monitor (fun () ->
              f ~worker_state ~conn_state arg writer ) )

    let make_proto ~name ~bin_input ~bin_output =
      let name = maybe_generate_name ~prefix:"rpc_parallel_piped" ~name in
      Rpc.Pipe_rpc.create ~name ~version:0 ~bin_query:bin_input
        ~bin_response:bin_output ~bin_error:Error.bin_t ()
  end

  module Function_plain = struct
    type ('worker, 'query, 'response) t = ('query, 'response) Rpc.Rpc.t

    let make_impl ~monitor ~f protocol =
      Rpc.Rpc.implement protocol
        (fun ((_conn : Rpc.Connection.t), internal_conn_state) arg ->
          let {Utils.Internal_connection_state.conn_state; worker_state; _} =
            Set_once.get_exn internal_conn_state [%here]
          in
          (* We want to raise any exceptions from [f arg] to the current monitor (handled
               by Rpc) so the caller can see it. Additional exceptions will be handled by the
               specified monitor *)
          Utils.try_within_exn ~monitor (fun () ->
              f ~worker_state ~conn_state arg ) )

    let make_proto ~name ~bin_input ~bin_output =
      let name = maybe_generate_name ~prefix:"rpc_parallel_plain" ~name in
      Rpc.Rpc.create ~name ~version:0 ~bin_query:bin_input
        ~bin_response:bin_output
  end

  module Function_reverse_piped = struct
    module Id = Unique_id.Int ()

    type ('worker, 'query, 'update, 'response) t =
      { worker_rpc: ('query * Id.t, 'response) Rpc.Rpc.t
      ; master_rpc: (Id.t, 'update, Error.t) Rpc.Pipe_rpc.t
      ; master_in_progress: 'update Pipe.Reader.t Id.Table.t }

    let make_worker_impl ~monitor ~f t =
      Rpc.Rpc.implement t.worker_rpc
        (fun (conn, internal_conn_state) (arg, id) ->
          let {Utils.Internal_connection_state.conn_state; worker_state; _} =
            Set_once.get_exn internal_conn_state [%here]
          in
          Utils.try_within_exn ~monitor (fun () ->
              Rpc.Pipe_rpc.dispatch t.master_rpc conn id
              >>= function
              | Ok (Ok (updates, (_ : Rpc.Pipe_rpc.Metadata.t))) ->
                  f ~worker_state ~conn_state arg updates
              | Ok (Error error) | Error error -> Error.raise error ) )

    let make_master_impl t =
      Rpc.Pipe_rpc.implement t.master_rpc (fun () id ->
          match Hashtbl.find_and_remove t.master_in_progress id with
          | None ->
              Deferred.Or_error.error_s
                [%message
                  "Bug in Rpc_parallel: reverse pipe master implementation \
                   not found"
                    (id : Id.t)
                    (Rpc.Pipe_rpc.name t.master_rpc : string)]
          | Some pipe_reader -> Deferred.Or_error.return pipe_reader )

    let make_proto ~name ~bin_query ~bin_update ~bin_response =
      let name =
        maybe_generate_name ~prefix:"rpc_parallel_reverse_piped" ~name
      in
      let worker_rpc =
        let module With_id = struct
          type 'a t = 'a * Id.t [@@deriving bin_io]
        end in
        Rpc.Rpc.create ~name ~version:0 ~bin_query:(With_id.bin_t bin_query)
          ~bin_response
      in
      let master_rpc =
        Rpc.Pipe_rpc.create ~name ~version:0 ~bin_query:Id.bin_t
          ~bin_response:bin_update ~bin_error:Error.bin_t ()
      in
      let master_in_progress = Id.Table.create () in
      {worker_rpc; master_rpc; master_in_progress}
  end

  module Function_one_way = struct
    type ('worker, 'query) t = 'query Rpc.One_way.t

    let make_impl ~monitor ~f protocol =
      Rpc.One_way.implement protocol
        (fun ((_conn : Rpc.Connection.t), internal_conn_state) arg ->
          let {Utils.Internal_connection_state.conn_state; worker_state; _} =
            Set_once.get_exn internal_conn_state [%here]
          in
          don't_wait_for
            (* Even though [f] returns [unit], we want to use [try_within_exn] so if it
                 starts any background jobs we won't miss the exceptions *)
            (Utils.try_within_exn ~monitor (fun () ->
                 f ~worker_state ~conn_state arg |> return )) )

    let make_proto ~name ~bin_input =
      let name =
        match name with
        | None ->
            sprintf "rpc_parallel_one_way_%s"
              (Rpc_id.to_string (Rpc_id.create ()))
        | Some n -> n
      in
      Rpc.One_way.create ~name ~version:0 ~bin_msg:bin_input
  end

  type ('worker, 'query, 'response) t_internal =
    | Plain of ('worker, 'query, 'response) Function_plain.t
    | Piped :
        ('worker, 'query, 'response) Function_piped.t
        * ('r, 'response Pipe.Reader.t) Type_equal.t
        -> ('worker, 'query, 'r) t_internal
    | Directly_piped :
        ('worker, 'query, 'response) Function_piped.t
        -> ( 'worker
           , 'query
             * (   'response Rpc.Pipe_rpc.Pipe_message.t
                -> Rpc.Pipe_rpc.Pipe_response.t)
           , Rpc.Pipe_rpc.Id.t )
           t_internal
    | One_way :
        ('worker, 'query) Function_one_way.t
        -> ('worker, 'query, unit) t_internal
    | Reverse_piped :
        ('worker, 'query, 'update, 'response) Function_reverse_piped.t
        * ('q, 'query * 'update Pipe.Reader.t) Type_equal.t
        -> ('worker, 'q, 'response) t_internal

  type ('worker, 'query, 'response) t =
    | T :
        ('query -> 'query_internal)
        * ('worker, 'query_internal, 'response_internal) t_internal
        * ('response_internal -> 'response)
        -> ('worker, 'query, 'response) t

  module Direct_pipe = struct
    type nonrec ('worker, 'query, 'response) t =
      ( 'worker
      , 'query
        * (   'response Rpc.Pipe_rpc.Pipe_message.t
           -> Rpc.Pipe_rpc.Pipe_response.t)
      , Rpc.Pipe_rpc.Id.t )
      t
  end

  let map (T (q, i, r)) ~f = T (q, i, Fn.compose f r)

  let contra_map (T (q, i, r)) ~f = T (Fn.compose q f, i, r)

  let create_rpc ~monitor ~name ~f ~bin_input ~bin_output =
    let proto = Function_plain.make_proto ~name ~bin_input ~bin_output in
    let impl = Function_plain.make_impl ~monitor ~f proto in
    (T (Fn.id, Plain proto, Fn.id), impl)

  let create_pipe ~monitor ~name ~f ~bin_input ~bin_output =
    let proto = Function_piped.make_proto ~name ~bin_input ~bin_output in
    let impl = Function_piped.make_impl ~monitor ~f proto in
    (T (Fn.id, Piped (proto, Type_equal.T), Fn.id), impl)

  let create_direct_pipe ~monitor ~name ~f ~bin_input ~bin_output =
    let proto = Function_piped.make_proto ~name ~bin_input ~bin_output in
    let impl = Function_piped.make_direct_impl ~monitor ~f proto in
    (T (Fn.id, Directly_piped proto, Fn.id), impl)

  let create_one_way ~monitor ~name ~f ~bin_input =
    let proto = Function_one_way.make_proto ~name ~bin_input in
    let impl = Function_one_way.make_impl ~monitor ~f proto in
    (T (Fn.id, One_way proto, Fn.id), impl)

  let create_reverse_pipe ~monitor ~name ~f ~bin_query ~bin_update
      ~bin_response =
    let proto =
      Function_reverse_piped.make_proto ~name ~bin_query ~bin_update
        ~bin_response
    in
    let worker_impl =
      Function_reverse_piped.make_worker_impl ~monitor ~f proto
    in
    let master_impl = Function_reverse_piped.make_master_impl proto in
    ( T (Fn.id, Reverse_piped (proto, Type_equal.T), Fn.id)
    , `Worker worker_impl
    , `Master master_impl )

  let of_async_rpc ~monitor ~f proto =
    let impl = Function_plain.make_impl ~monitor ~f proto in
    (T (Fn.id, Plain proto, Fn.id), impl)

  let of_async_pipe_rpc ~monitor ~f proto =
    let impl = Function_piped.make_impl ~monitor ~f proto in
    (T (Fn.id, Piped (proto, Type_equal.T), Fn.id), impl)

  let of_async_direct_pipe_rpc ~monitor ~f proto =
    let impl = Function_piped.make_direct_impl ~monitor ~f proto in
    (T (Fn.id, Directly_piped proto, Fn.id), impl)

  let of_async_one_way_rpc ~monitor ~f proto =
    let impl = Function_one_way.make_impl ~monitor ~f proto in
    (T (Fn.id, One_way proto, Fn.id), impl)

  let run_internal (type query response)
      (t_internal : (_, query, response) t_internal) connection ~(arg : query)
      : response Or_error.t Deferred.t =
    match t_internal with
    | Plain proto -> Rpc.Rpc.dispatch proto connection arg
    | Piped (proto, Type_equal.T) ->
        Rpc.Pipe_rpc.dispatch proto connection arg
        >>| fun result ->
        Or_error.join result |> Or_error.map ~f:(fun (reader, _) -> reader)
    | One_way proto -> Rpc.One_way.dispatch proto connection arg |> return
    | Reverse_piped
        ({worker_rpc; master_rpc= _; master_in_progress}, Type_equal.T) ->
        let query, updates = arg in
        let key = Function_reverse_piped.Id.create () in
        Hashtbl.add_exn master_in_progress ~key ~data:updates ;
        Rpc.Rpc.dispatch worker_rpc connection (query, key)
        >>| fun result ->
        Hashtbl.remove master_in_progress key ;
        result
    | Directly_piped proto ->
        let arg, f = arg in
        Rpc.Pipe_rpc.dispatch_iter proto connection arg ~f >>| Or_error.join

  let run (T (query_f, t_internal, response_f)) connection ~arg =
    run_internal t_internal connection ~arg:(query_f arg)
    >>| Or_error.map ~f:response_f

  let async_log = T (Fn.id, Piped (Async_log_rpc.rpc, Type_equal.T), Fn.id)

  let close_server = T (Fn.id, One_way Close_server_rpc.rpc, Fn.id)
end

module Daemonize_args = struct
  type args =
    { umask: int option
    ; redirect_stderr: Fd_redirection.t
    ; redirect_stdout: Fd_redirection.t }
  [@@deriving sexp]

  type t = [`Don't_daemonize | `Daemonize of args] [@@deriving sexp]
end

module Heartbeater_master : sig
  type t [@@deriving bin_io]

  val create :
    host_and_port:Host_and_port.t -> rpc_settings:Rpc_settings.t -> t

  val connect_and_shutdown_on_disconnect_exn : t -> [`Connected] Deferred.t
end = struct
  type t = {host_and_port: Host_and_port.t; rpc_settings: Rpc_settings.t}
  [@@deriving bin_io]

  let create ~host_and_port ~rpc_settings = {host_and_port; rpc_settings}

  let connect_and_wait_for_disconnect_exn {host_and_port; rpc_settings} =
    let {Rpc_settings.handshake_timeout; heartbeat_config; _} = rpc_settings in
    Rpc.Connection.client
      (Tcp.Where_to_connect.of_host_and_port host_and_port)
      ?handshake_timeout ?heartbeat_config
    >>| function
    | Error e -> raise e
    | Ok conn ->
        `Connected
          (Rpc.Connection.close_finished conn >>| fun () -> `Disconnected)

  let connect_and_shutdown_on_disconnect_exn heartbeater =
    connect_and_wait_for_disconnect_exn heartbeater
    >>= fun (`Connected wait_for_disconnect) ->
    ( wait_for_disconnect
    >>> fun `Disconnected ->
    Log.Global.error
      "Rpc_parallel: Heartbeater with master lost connection... Shutting down." ;
    Shutdown.shutdown 254 ) ;
    return `Connected
end

module type Worker =
  Worker with type ('w, 'q, 'r) _function := ('w, 'q, 'r) Function.t

module type Functions = Functions

module type Creator =
  Creator
  with type ('w, 'q, 'r) _function := ('w, 'q, 'r) Function.t
   and type ('w, 'q, 'r) _direct := ('w, 'q, 'r) Function.Direct_pipe.t

module type Worker_spec =
  Worker_spec
  with type ('w, 'q, 'r) _function := ('w, 'q, 'r) Function.t
   and type ('w, 'q, 'r) _direct := ('w, 'q, 'r) Function.Direct_pipe.t

let start_server ~max_message_size ~handshake_timeout ~heartbeat_config
    ~where_to_listen ~implementations ~initial_connection_state =
  let implementations =
    Rpc.Implementations.create_exn ~implementations
      ~on_unknown_rpc:`Close_connection
  in
  Rpc.Connection.serve ~implementations ~initial_connection_state
    ?max_message_size ?handshake_timeout ?heartbeat_config ~where_to_listen ()

module Worker_config = struct
  type t =
    { worker_type: Worker_type_id.t
    ; worker_id: Worker_id.t
    ; name: string option
    ; master: Host_and_port.t
    ; app_rpc_settings: Rpc_settings.t
    ; cd: string
    ; daemonize_args: Daemonize_args.t
    ; connection_timeout: Time.Span.t
    ; worker_command_args: [`Decorate_with_name | `User_supplied of string list]
    }
  [@@deriving fields, sexp]
end

module Worker_env = struct
  type t = {config: Worker_config.t; maybe_release_daemon: unit -> unit}
  [@@deriving fields]
end

(* Rpcs implemented by master *)
module Register_rpc = struct
  type t = Worker_id.t * Host_and_port.t [@@deriving bin_io]

  type response = [`Shutdown | `Registered] [@@deriving bin_io]

  let rpc =
    Rpc.Rpc.create ~name:"register_worker_rpc" ~version:0 ~bin_query:bin_t
      ~bin_response

  let implementation =
    Rpc.Rpc.implement rpc (fun () (id, worker_hp) ->
        let global_state = get_master_state_exn () in
        match Hashtbl.find global_state.pending id with
        | None ->
            (* We already returned a failure to the [spawn_worker] caller *)
            return `Shutdown
        | Some ivar ->
            Ivar.fill ivar worker_hp ;
            return `Registered )
end

module Handle_exn_rpc = struct
  type t = {id: Worker_id.t; name: string option; error: Error.t}
  [@@deriving bin_io]

  let rpc =
    Rpc.Rpc.create ~name:"handle_worker_exn_rpc" ~version:0 ~bin_query:bin_t
      ~bin_response:Unit.bin_t

  let implementation =
    Rpc.Rpc.implement rpc (fun () {id; name; error} ->
        let global_state = get_master_state_exn () in
        let on_failure, monitor =
          Hashtbl.find_exn global_state.on_failures id
        in
        let name = Option.value ~default:(Worker_id.to_string id) name in
        let error = Error.tag error ~tag:name in
        (* We can't just run [on_failure error] because this will be caught by the Rpc
           monitor for this implementation. *)
        Scheduler.within ~monitor (fun () -> on_failure error) ;
        return () )
end

(* In order to spawn other workers, you must have an rpc server implementing
   [Register_rpc] and [Handle_exn_rpc] *)
let master_implementations =
  [Register_rpc.implementation; Handle_exn_rpc.implementation]

(* Setup some global state necessary to act as a master (i.e. spawn workers). This
   includes starting an Rpc server with [master_implementations] *)
let init_master_state ~rpc_max_message_size ~rpc_handshake_timeout
    ~rpc_heartbeat_config ~worker_command_args =
  match Set_once.get global_state with
  | Some _state -> failwith "Master state must not be set up twice"
  | None ->
      let app_rpc_settings =
        Rpc_settings.create ~max_message_size:rpc_max_message_size
          ~handshake_timeout:rpc_handshake_timeout
          ~heartbeat_config:rpc_heartbeat_config
      in
      (* Use [size:1] so there is minimal top-level overhead linking with Rpc_parallel *)
      let pending = Worker_id.Table.create ~size:1 () in
      let on_failures = Worker_id.Table.create ~size:1 () in
      let my_worker_servers = Worker_id.Table.create ~size:1 () in
      (* Lazily start our master rpc server *)
      let my_server =
        lazy
          ( start_server ~max_message_size:rpc_max_message_size
              ~handshake_timeout:rpc_handshake_timeout
              ~heartbeat_config:rpc_heartbeat_config
              ~where_to_listen:Tcp.Where_to_listen.of_port_chosen_by_os
              ~implementations:master_implementations
              ~initial_connection_state:(fun _ _ -> () )
          >>| fun server ->
          Host_and_port.create ~host:(Unix.gethostname ())
            ~port:(Tcp.Server.listening_on server) )
      in
      let as_master =
        {my_server; app_rpc_settings; pending; worker_command_args; on_failures}
      in
      let as_worker = {my_worker_servers; initialized= Set_once.create ()} in
      Set_once.set_exn global_state [%here] {as_master; as_worker}

module Make (S : Worker_spec) = struct
  module Id = Utils.Worker_id

  type t =
    { host_and_port: Host_and_port.t
    ; rpc_settings: Rpc_settings.t
    ; id: Worker_id.t
    ; name: string option }
  [@@deriving bin_io, sexp_of]

  type worker = t

  (* Internally we use [Worker_id.t] for all worker ids, but we want to expose an [Id]
     module that is specific to each worker. *)
  let id t = t.id

  type worker_state =
    { (* A unique identifier for each application of the [Make] functor.
         Because we are running the same executable and this is supposed to run at the
         top level, the master and the workers agree on these ids *)
      type_:
        Worker_type_id.t
        (* Persistent states associated with instances of this worker server *)
    ; states:
        S.Worker_state.t Worker_id.Table.t
        (* To facilitate cleanup in the [Shutdown_on.Disconnect] case *)
    ; mutable client_has_connected:
        bool (* Build up a list of all implementations for this worker type *)
    ; mutable implementations:
        ( S.Worker_state.t
        , S.Connection_state.t )
        Utils.Internal_connection_state.t
        Rpc.Implementation.t
        list
    ; mutable master_implementations: unit Rpc.Implementation.t list }

  let worker_state =
    { type_= Worker_type_id.create ()
    ; states= Worker_id.Table.create ~size:1 ()
    ; client_has_connected= false
    ; implementations= []
    ; master_implementations= [] }

  (* Schedule all worker implementations in [Monitor.main] so no exceptions are lost.
     Async log automatically throws its exceptions to [Monitor.main] so we can't make
     our own local monitor. We detach [Monitor.main] and send exceptions back to the
     master. *)
  let monitor = Monitor.main

  (* Rpcs implemented by this worker type. The implementations for some must be below
     because User_functions is defined below (by supplying a [Creator] module) *)
  module Init_worker_state_rpc = struct
    type query =
      { (* The heartbeater of the process that called [spawn] *)
        master: Heartbeater_master.t option (* The process that got spawned *)
      ; worker: Worker_id.t
      ; arg: S.Worker_state.init_arg
      ; initial_client_connection_timeout: Time.Span.t option }
    [@@deriving bin_io]

    let rpc =
      Rpc.Rpc.create
        ~name:
          (sprintf "worker_init_rpc_%s"
             (Worker_type_id.to_string worker_state.type_))
        ~version:0 ~bin_query ~bin_response:Unit.bin_t
  end

  module Init_connection_state_rpc = struct
    type query =
      { worker_id: Worker_id.t
      ; worker_shutdown_on_disconnect: bool
      ; arg: S.Connection_state.init_arg }
    [@@deriving bin_io]

    let rpc =
      Rpc.Rpc.create
        ~name:
          (sprintf "set_connection_state_rpc_%s"
             (Worker_type_id.to_string worker_state.type_))
        ~version:0 ~bin_query ~bin_response:Unit.bin_t
  end

  let run_executable where ~env ~worker_command_args ~input =
    Utils.create_worker_env ~extra:env
    |> return
    >>=? fun env ->
    match where with
    | Executable_location.Local ->
        Utils.our_binary ()
        >>=? fun our_binary ->
        Process.create ~prog:our_binary ~args:worker_command_args
          ~env:(`Extend env) ()
        >>|? fun p ->
        Writer.write_sexp (Process.stdin p) input ;
        p
    | Executable_location.Remote exec ->
        Remote_executable.run exec ~env ~args:worker_command_args
        >>|? fun p ->
        Writer.write_sexp (Process.stdin p) input ;
        p

  module Function_creator = struct
    type nonrec worker = worker

    type connection_state = S.Connection_state.t

    type worker_state = S.Worker_state.t

    let with_add_impl f =
      let func, impl = f () in
      worker_state.implementations <- impl :: worker_state.implementations ;
      func

    let create_rpc ?name ~f ~bin_input ~bin_output () =
      with_add_impl (fun () ->
          Function.create_rpc ~monitor ~name ~f ~bin_input ~bin_output )

    let create_pipe ?name ~f ~bin_input ~bin_output () =
      with_add_impl (fun () ->
          Function.create_pipe ~monitor ~name ~f ~bin_input ~bin_output )

    let create_direct_pipe ?name ~f ~bin_input ~bin_output () =
      with_add_impl (fun () ->
          Function.create_direct_pipe ~monitor ~name ~f ~bin_input ~bin_output
      )

    let create_one_way ?name ~f ~bin_input () =
      with_add_impl (fun () ->
          Function.create_one_way ~monitor ~name ~f ~bin_input )

    let create_reverse_pipe ?name ~f ~bin_query ~bin_update ~bin_response () =
      let func, `Worker worker_impl, `Master master_impl =
        Function.create_reverse_pipe ~monitor ~name ~f ~bin_query ~bin_update
          ~bin_response
      in
      worker_state.implementations
      <- worker_impl :: worker_state.implementations ;
      worker_state.master_implementations
      <- master_impl :: worker_state.master_implementations ;
      func

    let of_async_rpc ~f proto =
      with_add_impl (fun () -> Function.of_async_rpc ~monitor ~f proto)

    let of_async_pipe_rpc ~f proto =
      with_add_impl (fun () -> Function.of_async_pipe_rpc ~monitor ~f proto)

    let of_async_direct_pipe_rpc ~f proto =
      with_add_impl (fun () ->
          Function.of_async_direct_pipe_rpc ~monitor ~f proto )

    let of_async_one_way_rpc ~f proto =
      with_add_impl (fun () -> Function.of_async_one_way_rpc ~monitor ~f proto)
  end

  module User_functions = S.Functions (Function_creator)

  let functions = User_functions.functions

  let master_implementations : _ Rpc.Connection.Client_implementations.t =
    { connection_state= const ()
    ; implementations=
        Rpc.Implementations.create_exn
          ~implementations:worker_state.master_implementations
          ~on_unknown_rpc:`Close_connection }

  let serve ?max_message_size ?handshake_timeout ?heartbeat_config
      worker_state_init_arg =
    match Hashtbl.find worker_implementations worker_state.type_ with
    | None ->
        failwith
          "Worker could not find RPC implementations. Make sure the \
           Parallel.Make () functor is applied in the worker. It is suggested \
           to make this toplevel."
    | Some (Worker_implementations.T worker_implementations) ->
        start_server ~implementations:worker_implementations
          ~initial_connection_state:(fun _address connection ->
            (connection, Set_once.create ()) )
          ~max_message_size ~handshake_timeout ~heartbeat_config
          ~where_to_listen:Tcp.Where_to_listen.of_port_chosen_by_os
        >>= fun server ->
        let id = Worker_id.create () in
        let host = Unix.gethostname () in
        let port = Tcp.Server.listening_on server in
        let global_state = get_worker_state_exn () in
        Hashtbl.add_exn global_state.my_worker_servers ~key:id ~data:server ;
        User_functions.init_worker_state worker_state_init_arg
        >>| fun state ->
        Hashtbl.add_exn worker_state.states ~key:id ~data:state ;
        let rpc_settings =
          Rpc_settings.create ~max_message_size ~handshake_timeout
            ~heartbeat_config
        in
        { host_and_port= Host_and_port.create ~host ~port
        ; rpc_settings
        ; id
        ; name= None }

  module Connection = struct
    type t = {connection: Rpc.Connection.t; worker_id: Id.t}
    [@@deriving fields, sexp_of]

    let close t = Rpc.Connection.close t.connection

    let close_finished t = Rpc.Connection.close_finished t.connection

    let close_reason t = Rpc.Connection.close_reason t.connection

    let is_closed t = Rpc.Connection.is_closed t.connection

    let client_aux ~worker_shutdown_on_disconnect
        {host_and_port; rpc_settings; id= worker_id; _} init_arg =
      let {Rpc_settings.max_message_size; handshake_timeout; heartbeat_config}
          =
        rpc_settings
      in
      Rpc.Connection.client ?max_message_size ?handshake_timeout
        ?heartbeat_config ~implementations:master_implementations
        (Tcp.Where_to_connect.of_host_and_port host_and_port)
      >>= function
      | Error exn -> return (Error (Error.of_exn exn))
      | Ok connection -> (
          Rpc.Rpc.dispatch Init_connection_state_rpc.rpc connection
            {worker_id; worker_shutdown_on_disconnect; arg= init_arg}
          >>= function
          | Error e -> Rpc.Connection.close connection >>| fun () -> Error e
          | Ok () -> Deferred.Or_error.return {connection; worker_id} )

    let client = client_aux ~worker_shutdown_on_disconnect:false

    let client_with_worker_shutdown_on_disconnect =
      client_aux ~worker_shutdown_on_disconnect:true

    let client_exn worker init_arg = client worker init_arg >>| Or_error.ok_exn

    let with_client worker init_arg ~f =
      client worker init_arg
      >>=? fun conn ->
      Monitor.try_with (fun () -> f conn)
      >>= fun result ->
      close conn
      >>| fun () -> Result.map_error result ~f:(fun exn -> Error.of_exn exn)

    let run t ~f ~arg = Function.run f t.connection ~arg

    let run_exn t ~f ~arg = run t ~f ~arg >>| Or_error.ok_exn
  end

  module Shutdown_on (M : T1) = struct
    type _ t =
      | Heartbeater_timeout : worker M.t Deferred.t t
      | Disconnect
          : (   connection_state_init_arg:S.Connection_state.init_arg
             -> Connection.t M.t Deferred.t)
            t
      | Called_shutdown_function : worker M.t Deferred.t t

    let args : type a.
           a t
        -> [`Client_will_immediately_connect of bool]
           * [`Setup_master_heartbeater of bool] = function
      | Heartbeater_timeout ->
          ( `Client_will_immediately_connect false
          , `Setup_master_heartbeater true )
      | Disconnect ->
          (* No heartbeater needed because we call
           [Connection.client_with_worker_shutdown_on_disconnect] and the worker shuts
           itself down if it times out waiting for a connection from the master. *)
          ( `Client_will_immediately_connect true
          , `Setup_master_heartbeater false )
      | Called_shutdown_function ->
          ( `Client_will_immediately_connect false
          , `Setup_master_heartbeater false )
  end

  type 'a with_spawn_args =
       ?where:Executable_location.t
    -> ?name:string
    -> ?env:(string * string) list
    -> ?connection_timeout:Time.Span.t
    -> ?cd:string
    -> on_failure:(Error.t -> unit)
    -> 'a

  (* This timeout serves three purposes.

     [spawn] returns an error if:
     (1) the master hasn't gotten a register rpc from the spawned worker within
     [connection_timeout] of sending the register rpc.
     (2) a worker hasn't gotten its [init_arg] from the master within [connection_timeout]
     of sending the register rpc

     Additionally, if [~shutdown_on:Disconnect] was used:
     (3) a worker will shut itself down if it doesn't get a connection from the master
     after spawn succeeded. *)
  let connection_timeout_default = sec 10.

  let spawn_process ~where ~env ~cd ~name ~connection_timeout ~daemonize_args =
    let where = Option.value where ~default:Executable_location.Local in
    let env = Option.value env ~default:[] in
    let cd = Option.value cd ~default:"/" in
    let connection_timeout =
      Option.value connection_timeout ~default:connection_timeout_default
    in
    ( match Set_once.get global_state with
    | None ->
        Deferred.Or_error.error_string
          "You must initialize this process to run as a master before calling \
           [spawn]. Either use a top-level [start_app] call or use the \
           [Expert] module."
    | Some global_state -> Deferred.Or_error.return global_state.as_master )
    >>=? fun global_state ->
    (* generate a unique identifier for this worker *)
    let id = Worker_id.create () in
    Lazy.force global_state.my_server
    >>= fun master_server ->
    let input =
      { Worker_config.worker_type= worker_state.type_
      ; worker_id= id
      ; name
      ; master= master_server
      ; app_rpc_settings= global_state.app_rpc_settings
      ; cd
      ; daemonize_args
      ; connection_timeout
      ; worker_command_args= global_state.worker_command_args }
      |> Worker_config.sexp_of_t
    in
    let pending_ivar = Ivar.create () in
    let worker_command_args =
      match global_state.worker_command_args with
      | `Decorate_with_name ->
          ["RPC_PARALLEL_WORKER"]
          @ Option.value_map name ~default:[] ~f:(fun name -> [name])
      | `User_supplied args -> args
    in
    Hashtbl.add_exn global_state.pending ~key:id ~data:pending_ivar ;
    run_executable where ~env ~worker_command_args ~input
    >>| function
    | Error _ as err ->
        Hashtbl.remove global_state.pending id ;
        err
    | Ok process -> Ok (id, process)

  let with_client worker ~f =
    let {host_and_port; rpc_settings; _} = worker in
    let {Rpc_settings.max_message_size; handshake_timeout; heartbeat_config} =
      rpc_settings
    in
    Rpc.Connection.with_client ?max_message_size ?handshake_timeout
      ?heartbeat_config ~implementations:master_implementations
      (Tcp.Where_to_connect.of_host_and_port host_and_port)
      f

  let shutdown worker =
    with_client worker ~f:(fun conn ->
        Rpc.One_way.dispatch Shutdown_rpc.rpc conn () |> return )
    >>| Or_error.of_exn_result >>| Or_error.join

  let with_shutdown_on_error worker ~f =
    f ()
    >>= function
    | Ok _ as ret -> return ret
    | Error _ as ret ->
        shutdown worker >>= fun (_ : unit Or_error.t) -> return ret

  let wait_for_connection_and_initialize ~name ~connection_timeout ~on_failure
      ~id ~client_will_immediately_connect ~setup_master_heartbeater init_arg =
    let connection_timeout =
      Option.value connection_timeout ~default:connection_timeout_default
    in
    let global_state = get_master_state_exn () in
    let pending_ivar = Hashtbl.find_exn global_state.pending id in
    (* Ensure that we got a register from the worker *)
    Clock.with_timeout connection_timeout (Ivar.read pending_ivar)
    >>= function
    | `Timeout ->
        Hashtbl.remove global_state.pending id ;
        Deferred.Or_error.error_string
          "Timed out getting connection from process"
    | `Result host_and_port ->
        Hashtbl.remove global_state.pending id ;
        let worker =
          {host_and_port; rpc_settings= global_state.app_rpc_settings; id; name}
        in
        Lazy.force global_state.my_server
        >>= fun master_server ->
        Hashtbl.add_exn global_state.on_failures ~key:worker.id
          ~data:(on_failure, Monitor.current ()) ;
        with_shutdown_on_error worker ~f:(fun () ->
            with_client worker ~f:(fun conn ->
                let heartbeater =
                  Option.some_if setup_master_heartbeater
                    (Heartbeater_master.create ~host_and_port:master_server
                       ~rpc_settings:global_state.app_rpc_settings)
                in
                Rpc.Rpc.dispatch Init_worker_state_rpc.rpc conn
                  { master= heartbeater
                  ; worker= id
                  ; arg= init_arg
                  ; initial_client_connection_timeout=
                      Option.some_if client_will_immediately_connect
                        connection_timeout } )
            >>| function
            | Error exn ->
                Hashtbl.remove global_state.on_failures worker.id ;
                Error (Error.of_exn exn)
            | Ok (Error e) ->
                Hashtbl.remove global_state.on_failures worker.id ;
                Error e
            | Ok (Ok ()) -> Ok worker )

  module Spawn_in_foreground_result = struct
    type 'a t = ('a * Process.t) Or_error.t
  end

  module Spawn_in_foreground_shutdown_on =
    Shutdown_on (Spawn_in_foreground_result)

  let spawn_in_foreground (type a) ?where ?name ?env ?connection_timeout ?cd
      ~on_failure ~(shutdown_on : a Spawn_in_foreground_shutdown_on.t)
      worker_state_init_arg : a =
    let open Spawn_in_foreground_shutdown_on in
    let daemonize_args = `Don't_daemonize in
    let ( `Client_will_immediately_connect client_will_immediately_connect
        , `Setup_master_heartbeater setup_master_heartbeater ) =
      args shutdown_on
    in
    let spawn_worker ~client_will_immediately_connect ~setup_master_heartbeater
        =
      spawn_process ~where ~env ~cd ~name ~connection_timeout ~daemonize_args
      >>= function
      | Error e -> return (Error e)
      | Ok (id, process) ->
          wait_for_connection_and_initialize ~name ~connection_timeout
            ~on_failure ~id ~client_will_immediately_connect
            ~setup_master_heartbeater worker_state_init_arg
          >>| Or_error.map ~f:(fun worker -> (worker, process))
    in
    match shutdown_on with
    | Heartbeater_timeout ->
        spawn_worker ~client_will_immediately_connect ~setup_master_heartbeater
    | Disconnect ->
        fun ~connection_state_init_arg ->
          spawn_worker ~client_will_immediately_connect
            ~setup_master_heartbeater
          >>=? fun (worker, process) ->
          (* If [Connection_state.init] raises, [client_internal] will close the Rpc
           connection, causing the worker to shutdown. *)
          Connection.client_with_worker_shutdown_on_disconnect worker
            connection_state_init_arg
          >>|? fun conn -> (conn, process)
    | Called_shutdown_function ->
        spawn_worker ~client_will_immediately_connect ~setup_master_heartbeater

  module Spawn_in_foreground_exn_result = struct
    type 'a t = 'a * Process.t
  end

  module Spawn_in_foreground_exn_shutdown_on =
    Shutdown_on (Spawn_in_foreground_exn_result)

  let spawn_in_foreground_exn (type a) ?where ?name ?env ?connection_timeout
      ?cd ~on_failure ~(shutdown_on : a Spawn_in_foreground_exn_shutdown_on.t)
      init_arg : a =
    let open Spawn_in_foreground_exn_shutdown_on in
    match shutdown_on with
    | Disconnect ->
        fun ~connection_state_init_arg ->
          spawn_in_foreground ?where ?name ?env ?connection_timeout ?cd
            ~on_failure ~shutdown_on:Disconnect init_arg
            ~connection_state_init_arg
          >>| ok_exn
    | Heartbeater_timeout ->
        spawn_in_foreground ?where ?name ?env ?connection_timeout ?cd
          ~on_failure ~shutdown_on:Heartbeater_timeout init_arg
        >>| ok_exn
    | Called_shutdown_function ->
        spawn_in_foreground ?where ?name ?env ?connection_timeout ?cd
          ~on_failure ~shutdown_on:Called_shutdown_function init_arg
        >>| ok_exn

  let wait_for_daemonization_and_collect_stderr name process =
    Writer.close (Process.stdin process)
    >>= fun () ->
    Process.wait process
    >>= fun exit_or_signal ->
    Reader.close (Process.stdout process)
    >>= fun () ->
    let worker_stderr = Reader.lines (Process.stderr process) in
    Pipe.iter worker_stderr ~f:(fun line ->
        let line' = sprintf "[WORKER %s STDERR]: %s\n" name line in
        Writer.write (Lazy.force Writer.stderr) line' |> return )
    >>| fun () ->
    match exit_or_signal with
    | Ok () -> Ok ()
    | Error _ ->
        let error_string =
          sprintf "Worker process %s"
            (Unix.Exit_or_signal.to_string_hum exit_or_signal)
        in
        Error (Error.of_string error_string)

  module Spawn_shutdown_on = Shutdown_on (Or_error)

  let spawn (type a) ?where ?name ?env ?connection_timeout ?cd ~on_failure
      ?umask ~(shutdown_on : a Spawn_shutdown_on.t) ~redirect_stdout
      ~redirect_stderr worker_state_init_arg : a =
    let daemonize_args =
      `Daemonize {Daemonize_args.umask; redirect_stderr; redirect_stdout}
    in
    let ( `Client_will_immediately_connect client_will_immediately_connect
        , `Setup_master_heartbeater setup_master_heartbeater ) =
      Spawn_shutdown_on.args shutdown_on
    in
    let spawn_worker ~client_will_immediately_connect ~setup_master_heartbeater
        =
      spawn_process ~where ~env ~cd ~name ~connection_timeout ~daemonize_args
      >>= function
      | Error e -> return (Error e)
      | Ok (id, process) -> (
          let id_or_name =
            Option.value ~default:(Worker_id.to_string id) name
          in
          wait_for_daemonization_and_collect_stderr id_or_name process
          >>= function
          | Error e -> return (Error e)
          | Ok () ->
              wait_for_connection_and_initialize ~name ~connection_timeout
                ~on_failure ~id ~client_will_immediately_connect
                ~setup_master_heartbeater worker_state_init_arg )
    in
    let open Spawn_shutdown_on in
    match shutdown_on with
    | Heartbeater_timeout ->
        spawn_worker ~client_will_immediately_connect ~setup_master_heartbeater
    | Disconnect ->
        fun ~connection_state_init_arg ->
          spawn_worker ~client_will_immediately_connect
            ~setup_master_heartbeater
          >>=? fun worker ->
          (* If [Connection_state.init] raises, [client_internal] will close the Rpc
           connection, causing the worker to shutdown. *)
          Connection.client_with_worker_shutdown_on_disconnect worker
            connection_state_init_arg
    | Called_shutdown_function ->
        spawn_worker ~client_will_immediately_connect ~setup_master_heartbeater

  module Spawn_exn_shutdown_on = Shutdown_on (Monad.Ident)

  let spawn_exn (type a) ?where ?name ?env ?connection_timeout ?cd ~on_failure
      ?umask ~(shutdown_on : a Spawn_exn_shutdown_on.t) ~redirect_stdout
      ~redirect_stderr init_arg : a =
    let open Spawn_exn_shutdown_on in
    match shutdown_on with
    | Disconnect ->
        fun ~connection_state_init_arg ->
          spawn ?where ?name ?env ?connection_timeout ?cd ~on_failure ?umask
            ~shutdown_on:Disconnect ~redirect_stdout ~redirect_stderr init_arg
            ~connection_state_init_arg
          >>| ok_exn
    | Heartbeater_timeout ->
        spawn ?where ?name ?env ?connection_timeout ?cd ~on_failure ?umask
          ~shutdown_on:Heartbeater_timeout ~redirect_stdout ~redirect_stderr
          init_arg
        >>| ok_exn
    | Called_shutdown_function ->
        spawn ?where ?name ?env ?connection_timeout ?cd ~on_failure ?umask
          ~shutdown_on:Called_shutdown_function ~redirect_stdout
          ~redirect_stderr init_arg
        >>| ok_exn

  module Deprecated = struct
    let spawn_and_connect ?where ?name ?env ?connection_timeout ?cd ~on_failure
        ?umask ~redirect_stdout ~redirect_stderr ~connection_state_init_arg
        worker_state_init_arg =
      spawn ?where ?name ?env ?connection_timeout ?cd ?umask ~redirect_stdout
        ~redirect_stderr ~on_failure ~shutdown_on:Heartbeater_timeout
        worker_state_init_arg
      >>=? fun worker ->
      with_shutdown_on_error worker ~f:(fun () ->
          Connection.client worker connection_state_init_arg )
      >>| Or_error.map ~f:(fun conn -> (worker, conn))

    let spawn_and_connect_exn ?where ?name ?env ?connection_timeout ?cd
        ~on_failure ?umask ~redirect_stdout ~redirect_stderr
        ~connection_state_init_arg worker_state_init_arg =
      spawn_and_connect ?where ?name ?env ?connection_timeout ?cd ~on_failure
        ?umask ~redirect_stdout ~redirect_stderr ~connection_state_init_arg
        worker_state_init_arg
      >>| ok_exn
  end

  let init_worker_state_impl =
    Rpc.Rpc.implement Init_worker_state_rpc.rpc
      (fun _conn_state
      { Init_worker_state_rpc.master
      ; worker
      ; arg
      ; initial_client_connection_timeout }
      ->
        let init_finished =
          Utils.try_within ~monitor (fun () ->
              let%bind () =
                match master with
                | None -> Deferred.unit
                | Some master ->
                    let%map `Connected =
                      Heartbeater_master.connect_and_shutdown_on_disconnect_exn
                        master
                    in
                    ()
              in
              User_functions.init_worker_state arg )
        in
        Set_once.set_exn (get_worker_state_exn ()).initialized [%here]
          (`Init_started (init_finished >>|? const `Initialized)) ;
        init_finished
        >>| function
        | Error e -> Error.raise e
        | Ok state ->
            ( match initial_client_connection_timeout with
            | None -> ()
            | Some timeout ->
                Clock.after timeout
                >>> fun () ->
                if not worker_state.client_has_connected then (
                  Log.Global.error
                    "Rpc_parallel: worker timed out waiting for client \
                     connection... Shutting down" ;
                  Shutdown.shutdown 254 ) ) ;
            Hashtbl.add_exn worker_state.states ~key:worker ~data:state )

  let init_connection_state_impl =
    Rpc.Rpc.implement Init_connection_state_rpc.rpc
      (fun (connection, internal_conn_state)
      {worker_id; worker_shutdown_on_disconnect; arg= init_arg}
      ->
        worker_state.client_has_connected <- true ;
        let worker_state = Hashtbl.find_exn worker_state.states worker_id in
        if worker_shutdown_on_disconnect then (
          Rpc.Connection.close_finished connection
          >>> fun () ->
          Log.Global.info
            "Rpc_parallel: initial client connection closed... Shutting down." ;
          Shutdown.shutdown 0 ) ;
        Utils.try_within_exn ~monitor (fun () ->
            User_functions.init_connection_state ~connection ~worker_state
              init_arg )
        >>| fun conn_state ->
        Set_once.set_exn internal_conn_state [%here]
          {Utils.Internal_connection_state.worker_id; conn_state; worker_state}
    )

  let shutdown_impl =
    Rpc.One_way.implement Shutdown_rpc.rpc (fun _conn_state () ->
        Log.Global.info "Rpc_parallel: Got shutdown rpc... Shutting down." ;
        Shutdown.shutdown 0 )

  let close_server_impl =
    Rpc.One_way.implement Close_server_rpc.rpc (fun (_conn, conn_state) () ->
        let {Utils.Internal_connection_state.worker_id; _} =
          Set_once.get_exn conn_state [%here]
        in
        let global_state = get_worker_state_exn () in
        match Hashtbl.find global_state.my_worker_servers worker_id with
        | None -> ()
        | Some tcp_server ->
            Tcp.Server.close tcp_server
            >>> fun () ->
            Hashtbl.remove global_state.my_worker_servers worker_id ;
            Hashtbl.remove worker_state.states worker_id )

  let async_log_impl =
    Rpc.Pipe_rpc.implement Async_log_rpc.rpc (fun _conn_state () ->
        let r, w = Pipe.create () in
        let new_output =
          Log.Output.create
            ~flush:(fun () -> Deferred.ignore (Pipe.downstream_flushed w))
            (fun msgs ->
              if not (Pipe.is_closed w) then
                Queue.iter msgs ~f:(fun msg ->
                    Pipe.write_without_pushback w msg ) ;
              return () )
        in
        Log.Global.set_output (new_output :: Log.Global.get_output ()) ;
        (* Remove this new output upon the pipe closing. *)
        upon (Pipe.closed w) (fun () ->
            let new_outputs =
              List.filter (Log.Global.get_output ()) ~f:(fun output ->
                  not (phys_equal output new_output) )
            in
            Log.Global.set_output new_outputs ) ;
        return (Ok r) )

  let () =
    worker_state.implementations
    <- [ init_worker_state_impl
       ; init_connection_state_impl
       ; shutdown_impl
       ; close_server_impl
       ; async_log_impl ]
       @ worker_state.implementations ;
    Hashtbl.add_exn worker_implementations ~key:worker_state.type_
      ~data:(Worker_implementations.T worker_state.implementations)
end

(* Start an Rpc server based on the implementations defined in the [Make] functor
   for this worker type. Return a [Host_and_port.t] describing the server *)
let worker_main ~worker_env =
  let {Worker_env.config; maybe_release_daemon} = worker_env in
  let {Rpc_settings.max_message_size; handshake_timeout; heartbeat_config} =
    Worker_config.app_rpc_settings config
  in
  let id = Worker_config.worker_id config in
  let register my_host_and_port =
    Rpc.Connection.with_client ?max_message_size ?handshake_timeout
      ?heartbeat_config (Tcp.Where_to_connect.of_host_and_port config.master)
      (fun conn -> Rpc.Rpc.dispatch Register_rpc.rpc conn (id, my_host_and_port)
    )
    >>| function
    | Error exn -> failwiths "Worker failed to register" exn [%sexp_of: Exn.t]
    | Ok (Error e) ->
        failwiths "Worker failed to register" e [%sexp_of: Error.t]
    | Ok (Ok `Shutdown) -> failwith "Got [`Shutdown] on register"
    | Ok (Ok `Registered) -> ()
  in
  (* We want the following two things to occur:

     (1) Catch exceptions in workers and report them back to the master
     (2) Write the exceptions to stderr *)
  let setup_exception_handling () =
    Scheduler.within (fun () ->
        Monitor.detach_and_get_next_error Monitor.main
        >>> fun exn ->
        (* We must be careful that this code here doesn't raise *)
        Rpc.Connection.with_client ?max_message_size ?handshake_timeout
          ?heartbeat_config
          (Tcp.Where_to_connect.of_host_and_port config.master) (fun conn ->
            Rpc.Rpc.dispatch Handle_exn_rpc.rpc conn
              {id; name= config.name; error= Error.of_exn exn} )
        >>> fun _ ->
        Log.Global.error !"Rpc_parallel: %{Exn} ... Shutting down." exn ;
        Shutdown.shutdown 254 )
  in
  (* Ensure we do not leak processes. Make sure we have initialized successfully, meaning
     we have heartbeats with the master established if the user wants them. *)
  let setup_cleanup_on_timeout () =
    Clock.after config.connection_timeout
    >>> fun () ->
    match Set_once.get (get_worker_state_exn ()).initialized with
    | None ->
        Log.Global.error
          "Rpc_parallel: Timeout getting Init_worker_state rpc from master... \
           Shutting down." ;
        Shutdown.shutdown 254
    | Some (`Init_started initialize_result) -> (
        initialize_result
        >>> function Ok `Initialized -> () | Error e -> Error.raise e )
  in
  match Hashtbl.find worker_implementations config.worker_type with
  | None ->
      failwith
        "Worker could not find RPC implementations. Make sure the \
         Parallel.Make () functor is applied in the worker. It is suggested \
         to make this toplevel."
  | Some (Worker_implementations.T worker_implementations) ->
      start_server ~implementations:worker_implementations
        ~initial_connection_state:(fun _address connection ->
          (connection, Set_once.create ()) )
        ~max_message_size ~handshake_timeout ~heartbeat_config
        ~where_to_listen:Tcp.Where_to_listen.of_port_chosen_by_os
      >>> fun server ->
      let host = Unix.gethostname () in
      let port = Tcp.Server.listening_on server in
      let global_state = get_worker_state_exn () in
      Hashtbl.add_exn global_state.my_worker_servers ~key:id ~data:server ;
      register (Host_and_port.create ~host ~port)
      >>> fun () ->
      setup_exception_handling () ;
      setup_cleanup_on_timeout () ;
      (* Daemonize as late as possible but still before running any user code. This lets
       us read any setup errors from stderr *)
      maybe_release_daemon ()

module Expert = struct
  module Worker_env = Worker_env

  let worker_init_before_async_exn () =
    match Utils.whoami () with
    | `Master ->
        failwith
          "[worker_init_before_async_exn] should not be called in a process \
           that was not spawned."
    | `Worker ->
        if Scheduler.is_running () then
          failwith
            "[worker_init_before_async_exn] must be called before the async \
             scheduler has been started." ;
        Utils.clear_env () ;
        let config =
          try Sexp.input_sexp In_channel.stdin |> Worker_config.t_of_sexp
          with _ ->
            failwith
              "Unable to read worker config from stdin. Make sure nothing is \
               read from stdin before [worker_init_before_async_exn] is \
               called."
        in
        let maybe_release_daemon =
          match config.daemonize_args with
          | `Don't_daemonize -> Core.Unix.chdir config.cd ; Fn.id
          | `Daemonize {Daemonize_args.umask; redirect_stderr; redirect_stdout}
            ->
              (* The worker is started via SSH. We want to go to the background so we can close
             the SSH connection, but not until we've connected back to the master via
             Rpc. This allows us to report any initialization errors to the master via the SSH
             connection. *)
              let redirect_stdout =
                Utils.to_daemon_fd_redirection redirect_stdout
              in
              let redirect_stderr =
                Utils.to_daemon_fd_redirection redirect_stderr
              in
              Staged.unstage
                (Daemon.daemonize_wait ~cd:config.cd ~redirect_stdout
                   ~redirect_stderr ?umask ())
        in
        {Worker_env.config; maybe_release_daemon}

  let start_worker_server_exn worker_env =
    let {Rpc_settings.max_message_size; handshake_timeout; heartbeat_config} =
      Worker_env.config worker_env |> Worker_config.app_rpc_settings
    in
    let worker_command_args =
      Worker_env.config worker_env |> Worker_config.worker_command_args
    in
    init_master_state ~rpc_max_message_size:max_message_size
      ~rpc_handshake_timeout:handshake_timeout
      ~rpc_heartbeat_config:heartbeat_config ~worker_command_args ;
    worker_main ~worker_env

  let start_master_server_exn ?rpc_max_message_size ?rpc_handshake_timeout
      ?rpc_heartbeat_config ~worker_command_args () =
    match Utils.whoami () with
    | `Worker -> failwith "Do not call [init_master_exn] in a spawned worker"
    | `Master ->
        init_master_state ~rpc_max_message_size ~rpc_handshake_timeout
          ~rpc_heartbeat_config
          ~worker_command_args:(`User_supplied worker_command_args)

  let worker_command =
    let open Command.Let_syntax in
    Command.async ~summary:"internal use only"
      [%map_open
        let () = return () in
        let worker_env = worker_init_before_async_exn () in
        fun () ->
          start_worker_server_exn worker_env ;
          Deferred.never ()]
end

module State = struct
  type t = [`started]

  let get () = Option.map (Set_once.get global_state) ~f:(fun _ -> `started)
end

let start_app ?rpc_max_message_size ?rpc_handshake_timeout
    ?rpc_heartbeat_config command =
  match Utils.whoami () with
  | `Worker ->
      let worker_env = Expert.worker_init_before_async_exn () in
      Expert.start_worker_server_exn worker_env ;
      never_returns (Scheduler.go ())
  | `Master ->
      init_master_state ~rpc_max_message_size ~rpc_handshake_timeout
        ~rpc_heartbeat_config ~worker_command_args:`Decorate_with_name ;
      Command.run command
