open Core
open Async

module Worker_id = struct
  let create = Uuid.create

  (* If we do not use the stable sexp serialization, when running
     inline tests, we will create UUIDs that fail tests *)
  module T = Uuid.Stable.V1

  type t = T.t [@@deriving sexp, bin_io]

  include Comparable.Make_binable (T)
  include Hashable.Make_binable (T)
  include Sexpable.To_stringable (T)

  let pp fmt t = String.pp fmt (Sexp.to_string ([%sexp_of: t] t))
end

module Worker_type_id = Unique_id.Int ()

module Internal_connection_state = struct
  type ('worker_state, 'conn_state) t1 =
    { worker_state: 'worker_state
    ; conn_state: 'conn_state
    ; worker_id: Worker_id.t }

  type ('worker_state, 'conn_state) t =
    Rpc.Connection.t * ('worker_state, 'conn_state) t1 Set_once.t
end

let try_within ~monitor f =
  let ivar = Ivar.create () in
  Scheduler.within ~monitor (fun () ->
      Monitor.try_with ~run:`Now ~rest:`Raise f
      >>> fun r -> Ivar.fill ivar (Result.map_error r ~f:Error.of_exn) ) ;
  Ivar.read ivar

let try_within_exn ~monitor f =
  try_within ~monitor f >>| function Ok x -> x | Error e -> Error.raise e

(* To get the currently running executable:
 * On Darwin:
 * Use _NSGetExecutablePath via Ctypes
 *
 * On Linux:
 * Use /proc/PID/exe
   - argv[0] might have been deleted (this is quite common with jenga)
   - `cp /proc/PID/exe dst` works as expected while `cp /proc/self/exe dst` does not *)
let our_binary =
  let our_binary_lazy =
    lazy
      (let open Deferred.Or_error.Let_syntax in
      let%map os = Process.run ~prog:"uname" ~args:["-s"] () in
      if os = "Darwin\n" then (
        let open Ctypes in
        let ns_get_executable_path =
          Foreign.foreign "_NSGetExecutablePath"
            (ptr char @-> ptr uint32_t @-> returning void)
        in
        let path_max = 1024 in
        let buf = Ctypes.allocate_n char ~count:path_max in
        let count =
          Ctypes.allocate uint32_t (Unsigned.UInt32.of_int (path_max - 1))
        in
        ns_get_executable_path buf count ;
        let s =
          string_from_ptr buf ~length:(!@count |> Unsigned.UInt32.to_int)
        in
        List.hd_exn @@ String.split s ~on:(Char.of_int 0 |> Option.value_exn) )
      else Unix.getpid () |> Pid.to_int |> sprintf "/proc/%d/exe")
  in
  fun () -> Lazy.force our_binary_lazy

let our_md5 =
  let our_md5_lazy =
    lazy
      (let open Deferred.Or_error.Let_syntax in
      let%bind our_binary = our_binary () in
      let%map our_md5 = Process.run ~prog:"md5sum" ~args:[our_binary] () in
      let our_md5, _ = String.lsplit2_exn ~on:' ' our_md5 in
      our_md5)
  in
  fun () -> Lazy.force our_md5_lazy

let is_child_env_var = "ASYNC_PARALLEL_IS_CHILD_MACHINE"

let whoami () =
  match Sys.getenv is_child_env_var with Some _ -> `Worker | None -> `Master

let clear_env () = Unix.unsetenv is_child_env_var

let validate_env env =
  match List.find env ~f:(fun (key, _) -> key = is_child_env_var) with
  | Some e ->
      Or_error.error
        "Environment variable conflicts with Rpc_parallel machinery" e
        [%sexp_of: string * string]
  | None -> Ok ()

let create_worker_env ~extra =
  let open Or_error.Monad_infix in
  validate_env extra >>| fun () -> extra @ [(is_child_env_var, "")]

let to_daemon_fd_redirection = function
  | `Dev_null -> `Dev_null
  | `File_append s -> `File_append s
  | `File_truncate s -> `File_truncate s
