(* conf_dir.ml -- config directory management *)

open Core

(** Compute the config directory to be used by the daemon. This method raises a
    user error exception if the MINA_HARDFORK_STATE_DIR environment variable is
    not equal to this config directory, if that environment variable is set. This
    allows the hard fork dispatcher to use that variable to refer to the config
    directory. *)
let compute_conf_dir_exn conf_dir_opt =
  let home = Sys_unix.home_directory () in
  let conf_dir =
    Option.value ~default:(home ^/ Cli_lib.Default.conf_dir_name) conf_dir_opt
  in
  ( match Sys.getenv "MINA_HARDFORK_STATE_DIR" with
  | Some hardfork_state_dir when not (String.equal conf_dir hardfork_state_dir)
    ->
      Mina_stdlib.Mina_user_error.raisef
        "The daemon configuration directory (%s) does not match the \
         MINA_HARDFORK_STATE_DIR environment variable (%s). Please ensure they \
         are consistent."
        conf_dir hardfork_state_dir ()
  | _ ->
      () ) ;
  conf_dir

(** Attempt to create the daemon lockfile in the [conf_dir], and otherwise throw
    an error (to signal shutdown) if this fails. The lockfile is acquired by a
    daemon during startup, before anything in the [conf_dir] is modified. It is
    used to prevent subsequent daemons from starting up in the [conf_dir] if a
    daemon already holds the lockfile.

    The lockfile is held by a process if the file exists, contains a PID, and
    that process has that PID. Since daemons can crash or be killed -
    interfering with daemon cleanup - it is possible for a lockfile to exist and
    yet not be held by any existing process. If such a lockfile exists, it must
    be removed by the daemon, and then the daemon must attempt to re-acquire the
    lockfile. *)
let rec check_and_set_lockfile ~logger conf_dir =
  let lockfile = conf_dir ^/ ".mina-lock" in
  match Sys_unix.file_exists lockfile with
  | `No -> (
      let open Async in
      match%map
        Monitor.try_with ~here:[%here] ~extract_exn:true (fun () ->
            Writer.with_file ~exclusive:true lockfile ~f:(fun writer ->
                let pid = Unix.getpid () in
                return (Writer.writef writer "%d\n" (Pid.to_int pid)) ) )
      with
      | Ok () ->
          [%log debug] "Created daemon lockfile $lockfile"
            ~metadata:[ ("lockfile", `String lockfile) ] ;
          Exit_handlers.register_async_shutdown_handler ~logger
            ~description:"Remove daemon lockfile" ~tier:ReleaseDaemonLockfile
            (fun () ->
              match%bind Sys.file_exists lockfile with
              | `Yes ->
                  Unix.unlink lockfile
              | _ ->
                  return () )
      | Error exn ->
          Error.tag_arg (Error.of_exn exn)
            "Could not create the daemon lockfile" ("lockfile", lockfile)
            [%sexp_of: string * string]
          |> Error.raise )
  | `Yes -> (
      let open Async in
      match%map
        Monitor.try_with ~here:[%here] ~extract_exn:true (fun () ->
            Reader.with_file ~exclusive:true lockfile ~f:(fun reader ->
                let%bind pid =
                  let rm_and_raise () =
                    Core_unix.unlink lockfile ;
                    Mina_stdlib.Mina_user_error.raise
                      "Invalid format in lockfile (removing it)"
                  in
                  match%map Reader.read_line reader with
                  | `Ok s -> (
                      try Pid.of_string s with _ -> rm_and_raise () )
                  | `Eof ->
                      rm_and_raise ()
                in
                let still_running =
                  (* using signal 0 does not send a signal; see man page `kill(2)` *)
                  match Signal_unix.send Signal.zero (`Pid pid) with
                  | `Ok ->
                      true
                  | `No_such_process ->
                      false
                in
                if still_running then
                  if Pid.equal pid (Unix.getpid ()) then
                    (* can happen when running in Docker *)
                    return ()
                  else
                    Mina_stdlib.Mina_user_error.raisef
                      "A daemon (process id %d) is already running with the \
                       current configuration directory (%s)"
                      (Pid.to_int pid) conf_dir
                else (
                  [%log info] "Removing lockfile for terminated process"
                    ~metadata:
                      [ ("lockfile", `String lockfile)
                      ; ("pid", `Int (Pid.to_int pid))
                      ] ;
                  let%bind () = Unix.unlink lockfile in
                  [%log info] "Re-attempting to acquire the lockfile" ;
                  check_and_set_lockfile ~logger conf_dir ) ) )
      with
      | Ok () ->
          ()
      | Error exn ->
          Error.tag_arg (Error.of_exn exn) "Error processing lockfile"
            ("lockfile", lockfile) [%sexp_of: string * string]
          |> Error.raise )
  | `Unknown ->
      Error.create "Could not determine whether the daemon lockfile exists"
        ("lockfile", lockfile) [%sexp_of: string * string]
      |> Error.raise

let get_hw_info () =
  let open Async in
  let%bind linux_info =
    if String.equal Sys.os_type "Unix" then
      match%map Process.run ~prog:"uname" ~args:[ "-a" ] () with
      | Ok s when String.is_prefix s ~prefix:"Linux" ->
          Some s
      | _ ->
          None
    else return None
  in
  if Option.is_some linux_info then
    let linux_hw_progs =
      [ ("lscpu", []); ("lsgpu", []); ("lsmem", []); ("lsblk", []) ]
    in
    let%map outputs =
      Deferred.List.map ~how:`Sequential linux_hw_progs ~f:(fun (prog, args) ->
          let header =
            sprintf "*** Output from '%s' ***\n"
              (String.concat ~sep:" " (prog :: args))
          in
          let%bind output =
            match%map Process.run_lines ~prog ~args () with
            | Ok lines ->
                lines
            | Error err ->
                [ sprintf "Error: %s" (Error.to_string_hum err) ]
          in
          return ((header :: output) @ [ "" ]) )
    in
    let os_release =
      let file = "/etc/os-release" in
      let contents =
        match In_channel.read_lines file with
        | lines ->
            lines
        | exception exn ->
            [ sprintf "Error: %s" (Exn.to_string exn) ]
      in
      (sprintf "*** Contents of '%s' ***\n" file :: contents) @ [ "" ]
    in
    Some ((Option.value_exn linux_info :: os_release) @ List.concat outputs)
  else (* TODO: Mac, other Unixes *)
    return None

let export_logs_to_tar ?basename ~conf_dir =
  let open Async in
  let open Deferred.Result.Let_syntax in
  let basename =
    match basename with
    | None ->
        let date, day = Time_float.(now () |> to_date_ofday ~zone:Zone.utc) in
        let Time_float.Span.Parts.{ hr; min; sec; _ } =
          Time_float.Ofday.to_parts day
        in
        sprintf "%s_%02d-%02d-%02d" (Date.to_string date) hr min sec
    | Some basename ->
        basename
  in
  let export_dir = conf_dir ^/ "exported_logs" in
  ( match Sys_unix.file_exists export_dir with
  | `No ->
      Core_unix.mkdir export_dir
  | _ ->
      () ) ;
  let tarfile = export_dir ^/ basename ^ ".tar.gz" in
  let log_files =
    Sys_unix.ls_dir conf_dir
    |> List.filter ~f:(String.is_substring ~substring:".log")
  in
  let%bind.Deferred hw_info_opt = get_hw_info () in
  let%bind.Deferred hw_file_opt =
    if Option.is_some hw_info_opt then
      let open Async in
      let hw_info = "hardware.info" in
      let hw_info_file = conf_dir ^/ hw_info in
      match%map
        Monitor.try_with ~here:[%here] ~extract_exn:true (fun () ->
            Writer.with_file ~exclusive:true hw_info_file ~f:(fun writer ->
                Deferred.List.map ~how:`Sequential
                  (Option.value_exn hw_info_opt) ~f:(fun line ->
                    return (Writer.write_line writer line) ) ) )
      with
      | Ok _units ->
          Some hw_info
      | Error _exn ->
          (* carry on, despite the error *)
          None
    else Deferred.return None
  in
  let base_files = "mina.version" :: log_files in
  let files =
    Option.value_map hw_file_opt ~default:base_files ~f:(fun hw_file ->
        hw_file :: base_files )
  in
  let tmp_dir =
    Filename_unix.temp_dir ~in_dir:"/tmp" ("mina-logs_" ^ basename) ""
  in
  (* Snapshot the files before archiving them: the daemon keeps writing to its
     logs, and tar would otherwise read them as they change underneath it.
     Permissions and timestamps are carried over, as [cp -p] used to do. *)
  let copy_file file =
    let open Deferred.Let_syntax in
    let src = conf_dir ^/ file and dst = tmp_dir ^/ file in
    match%map
      Monitor.try_with ~here:[%here] (fun () ->
          let%bind stats = Unix.stat src in
          let%bind () =
            Reader.with_file src ~f:(fun reader ->
                Writer.with_file dst ~f:(fun writer ->
                    Writer.transfer writer (Reader.pipe reader)
                      (Writer.write writer) ) )
          in
          let%bind () = Unix.chmod dst ~perm:stats.Unix.Stats.perm in
          let seconds t =
            Time_float.Span.to_sec (Time_float.to_span_since_epoch t)
          in
          Unix.utimes dst
            ~access:(seconds stats.Unix.Stats.atime)
            ~modif:(seconds stats.Unix.Stats.mtime) )
    with
    | Ok () ->
        true
    | Error _exn ->
        (* A log file can be rotated away underneath us; archive the rest. *)
        false
  in
  let%bind.Deferred copied =
    Deferred.List.filter ~how:`Sequential files ~f:copy_file
  in
  let%bind _result =
    Process.run ~prog:"tar"
      ~args:
        ( [ "-C"
          ; tmp_dir
          ; (* Create gzipped tar file [file]. *)
            "-czf"
          ; tarfile
          ]
        @ copied )
      ()
  in
  let%bind.Deferred () = Mina_stdlib_unix.File_system.remove_dir tmp_dir in
  Deferred.Or_error.return tarfile
