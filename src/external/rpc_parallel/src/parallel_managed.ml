open Core
open Async

module type Worker = sig
  type t [@@deriving sexp_of]
  type unmanaged_t

  type 'a functions

  val functions : unmanaged_t functions

  type worker_state_init_arg
  type connection_state_init_arg

  module Id : Identifiable
  val id : t -> Id.t

  val spawn
    :  ?where : Executable_location.t
    -> ?name : string
    -> ?env : (string * string) list
    -> ?connection_timeout:Time.Span.t
    -> ?cd : string
    -> ?umask : int
    -> redirect_stdout : Fd_redirection.t
    -> redirect_stderr : Fd_redirection.t
    -> worker_state_init_arg
    -> connection_state_init_arg
    -> on_failure : (Error.t -> unit)
    -> t Or_error.t Deferred.t

  val spawn_exn
    :  ?where : Executable_location.t
    -> ?name : string
    -> ?env : (string * string) list
    -> ?connection_timeout:Time.Span.t
    -> ?cd : string
    -> ?umask : int
    -> redirect_stdout : Fd_redirection.t
    -> redirect_stderr : Fd_redirection.t
    -> worker_state_init_arg
    -> connection_state_init_arg
    -> on_failure : (Error.t -> unit)
    -> t Deferred.t

  val run
    :  t
    -> f: (unmanaged_t, 'query, 'response) Parallel.Function.t
    -> arg: 'query
    -> 'response Or_error.t Deferred.t

  val run_exn
    :  t
    -> f: (unmanaged_t, 'query, 'response) Parallel.Function.t
    -> arg: 'query
    -> 'response Deferred.t

  val kill     : t -> unit Or_error.t Deferred.t
  val kill_exn : t -> unit Deferred.t
end

module Make (S : Parallel.Worker_spec) = struct
  module Unmanaged = Parallel.Make (S)
  module Id = Utils.Worker_id

  type nonrec t =
    { unmanaged : Unmanaged.t
    ; connection_state_init_arg : S.Connection_state.init_arg
    ; id : Id.t
    }

  type unmanaged_t = Unmanaged.t

  type conn =
    [ `Pending of Unmanaged.Connection.t Or_error.t Ivar.t
    | `Connected of Unmanaged.Connection.t ]

  let sexp_of_t t = [%sexp_of: Unmanaged.t] t.unmanaged

  let id t = t.id

  let functions = Unmanaged.functions

  let workers : conn Id.Table.t = Id.Table.create ()

  let get_connection { unmanaged = t; connection_state_init_arg; id } =
    match Hashtbl.find workers id with
    | Some (`Pending ivar) -> Ivar.read ivar
    | Some (`Connected conn) -> Deferred.Or_error.return conn
    | None ->
      let ivar = Ivar.create () in
      Hashtbl.add_exn workers ~key:id ~data:(`Pending ivar);
      Unmanaged.Connection.client t connection_state_init_arg
      >>| function
      | Error e ->
        Ivar.fill ivar (Error e);
        Hashtbl.remove workers id;
        Error e
      | Ok conn ->
        Ivar.fill ivar (Ok conn);
        Hashtbl.set workers ~key:id ~data:(`Connected conn);
        (Unmanaged.Connection.close_finished conn
         >>> fun () ->
         Hashtbl.remove workers id);
        Ok conn
  ;;

  let with_shutdown_on_error worker ~f =
    f ()
    >>= function
    | Ok _ as ret -> return ret
    | Error _ as ret ->
      Unmanaged.shutdown worker
      >>= fun (_ : unit Or_error.t) ->
      return ret
  ;;

  let spawn ?where ?name ?env
        ?connection_timeout ?cd ?umask ~redirect_stdout ~redirect_stderr
        worker_state_init_arg connection_state_init_arg ~on_failure =
    Unmanaged.spawn ?where ?env ?name
      ?connection_timeout ?cd ?umask ~shutdown_on:Heartbeater_timeout
      ~redirect_stdout ~redirect_stderr worker_state_init_arg ~on_failure
    >>=? fun worker ->
    with_shutdown_on_error worker ~f:(fun () ->
      Unmanaged.Connection.client worker connection_state_init_arg)
    >>|? fun connection ->
    let id = Id.create () in
    Hashtbl.add_exn workers ~key:id ~data:(`Connected connection);
    (Unmanaged.Connection.close_finished connection
     >>> fun () ->
     match Hashtbl.find workers id with
     | None ->
       (* [kill] was called, don't report closed connection *)
       ()
     | Some _ ->
       Hashtbl.remove workers id;
       let error =
         Error.createf !"Lost connection with worker"
       in
       on_failure error);
    { unmanaged = worker; connection_state_init_arg; id }
  ;;

  let spawn_exn ?where ?name ?env
        ?connection_timeout ?cd ?umask ~redirect_stdout ~redirect_stderr
        worker_state_init_arg connection_init_arg ~on_failure =
    spawn ?where ?name ?env
      ?connection_timeout ?cd ?umask ~redirect_stdout ~redirect_stderr
      worker_state_init_arg connection_init_arg ~on_failure
    >>| Or_error.ok_exn
  ;;

  let kill t =
    Hashtbl.remove workers t.id;
    Unmanaged.shutdown t.unmanaged
  ;;

  let kill_exn t = kill t >>| Or_error.ok_exn

  let run t ~f ~arg =
    get_connection t
    >>=? fun conn ->
    Unmanaged.Connection.run conn ~f ~arg
  ;;

  let run_exn t ~f ~arg =
    run t ~f ~arg
    >>| Or_error.ok_exn
  ;;
end
