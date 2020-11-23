(* conf_dir.ml -- config directory management *)

open Core

let compute_conf_dir conf_dir_opt =
  let home = Sys.home_directory () in
  Option.value ~default:(home ^/ Cli_lib.Default.conf_dir_name) conf_dir_opt

let check_and_set_lockfile ~logger conf_dir =
  let lockfile = conf_dir ^/ ".mina-lock" in
  match Sys.file_exists lockfile with
  | `No -> (
      let open Async in
      match%map
        Monitor.try_with ~extract_exn:true (fun () ->
            let open Unix in
            let%bind fd = openfile ~mode:[`Wronly; `Creat] lockfile in
            close fd )
      with
      | Ok () ->
          [%log info] "Created daemon lockfile $lockfile"
            ~metadata:[("lockfile", `String lockfile)] ;
          Exit_handlers.register_async_shutdown_handler ~logger
            ~description:"Remove daemon lockfile" (fun () ->
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
  | `Yes ->
      Mina_user_error.raisef
        "A daemon is already running with the current configuration directory \
         (%s), or you may need to remove the lockfile (%s)"
        conf_dir lockfile
  | `Unknown ->
      Error.create "Could not determine whether the daemon lockfile exists"
        ("lockfile", lockfile) [%sexp_of: string * string]
      |> Error.raise

let export_logs_to_tar ?basename ~conf_dir =
  let open Async in
  let open Deferred.Result.Let_syntax in
  let basename =
    match basename with
    | None ->
        let date, day = Time.(now () |> to_date_ofday ~zone:Zone.utc) in
        let Time.Span.Parts.{hr; min; sec; _} = Time.Ofday.to_parts day in
        sprintf "%s_%02d-%02d-%02d" (Date.to_string date) hr min sec
    | Some basename ->
        basename
  in
  let export_dir = conf_dir ^/ "exported_logs" in
  ( match Core.Sys.file_exists export_dir with
  | `No ->
      Core.Unix.mkdir export_dir
  | _ ->
      () ) ;
  let tarfile = export_dir ^/ basename ^ ".tgz" in
  let log_files =
    Core.Sys.ls_dir conf_dir
    |> List.filter ~f:(String.is_suffix ~suffix:".log")
  in
  let%map _result =
    Process.run ~prog:"tar"
      ~args:
        ( [ "-C"
          ; conf_dir
          ; (* Create gzipped tar file [file]. *)
            "-czf"
          ; tarfile ]
        @ log_files )
      ()
  in
  tarfile
