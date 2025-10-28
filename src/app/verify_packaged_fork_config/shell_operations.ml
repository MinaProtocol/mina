(** Shell command execution utilities.

    This module provides safe wrappers around shell command execution
    with logging, error handling, and environment variable management.
*)

open Core
open Async

(** Execute a shell command with optional environment variables.

    @param env Optional list of (key, value) environment variable pairs
    @param cmd The command string to execute
    @return Ok () on success, Error with message on failure
*)
let run_command ?(env = []) cmd =
  let env_vars =
    if List.is_empty env then ""
    else
      ( List.map env ~f:(fun (k, v) -> sprintf "%s=%s" k v)
      |> String.concat ~sep:" " )
      ^ " "
  in
  let full_cmd = env_vars ^ cmd in
  Log.Global.debug "Executing command: %s" full_cmd ;
  match%map Unix.system full_cmd with
  | Ok () ->
      Log.Global.debug "Command completed successfully: %s" full_cmd ;
      Ok ()
  | Error err ->
      let err_msg = Unix.Exit_or_signal.to_string_hum (Error err) in
      Log.Global.error "Command failed: %s (error: %s)" full_cmd err_msg ;
      Error err_msg

(** Execute a shell command and capture its stdout output.

    @param cmd The command string to execute
    @return Ok with output lines concatenated, or Error with message
*)
let run_command_capture cmd =
  Log.Global.debug "Executing command and capturing output: %s" cmd ;
  let%bind result = Process.run_lines ~prog:"bash" ~args:[ "-c"; cmd ] () in
  match result with
  | Ok output ->
      Log.Global.debug "Command output captured successfully (lines: %d)"
        (List.length output) ;
      return (Or_error.map result ~f:(String.concat ~sep:"\n"))
  | Error err ->
      Log.Global.error "Command failed to capture output: %s (error: %s)" cmd
        (Error.to_string_hum err) ;
      return (Or_error.map result ~f:(String.concat ~sep:"\n"))

(** Resolve an executable by checking environment variable first, then PATH/fallback.

    This function implements the standard lookup strategy:
    1. Check if environment variable is set
    2. Look for command in PATH
    3. Use fallback path if provided

    @param env_var Environment variable name to check
    @param cmd_name Command name to search in PATH
    @param fallback_path Fallback path to use if not found elsewhere
    @return Deferred string with the resolved executable path
    @raise Exit if executable cannot be found
*)
let resolve_executable_from_env env_var cmd_name fallback_path =
  match Sys.getenv env_var with
  | Some exe ->
      Log.Global.info "Using %s from environment: %s" env_var exe ;
      return exe
  | None -> (
      Log.Global.info "%s not set, searching for %s executable" env_var cmd_name ;
      Log.Global.debug "Checking if %s exists in PATH" cmd_name ;
      match%bind
        Unix.system (sprintf "command -v %s > /dev/null 2>&1" cmd_name)
      with
      | Ok () ->
          Log.Global.info "Found %s in PATH" cmd_name ;
          return cmd_name
      | Error _ -> (
          Log.Global.info
            "Command %s not found in PATH, checking fallback path: %s" cmd_name
            fallback_path ;
          match%bind Sys.file_exists fallback_path with
          | `Yes ->
              Log.Global.info "Found fallback executable at: %s" fallback_path ;
              return fallback_path
          | `No | `Unknown ->
              Log.Global.error
                "Error: %s not found in PATH (as %s) or relative to cwd (as %s)"
                cmd_name cmd_name fallback_path ;
              eprintf
                "Error: %s not found in PATH (as %s) or relative to cwd (as %s)\n\
                 %!"
                cmd_name cmd_name fallback_path ;
              exit 1 ) )

(** Resolve an executable with simple environment variable fallback.

    @param env_var Environment variable name to check
    @param default_value Default value if environment variable not set
    @return Deferred string with the resolved value
*)
let resolve_executable_simple env_var default_value =
  match Sys.getenv env_var with
  | Some exe ->
      Log.Global.info "Using %s from environment: %s" env_var exe ;
      return exe
  | None ->
      Log.Global.info "%s not set, using default: %s" env_var default_value ;
      return default_value

(** Get environment variable value with fallback to default.

    @param env_var Environment variable name
    @param default_value Default value if not set
    @return The environment variable value or default
*)
let get_env_or_default env_var default_value =
  match Sys.getenv env_var with
  | Some value ->
      Log.Global.debug "Using %s from environment: %s" env_var value ;
      value
  | None ->
      Log.Global.debug "Using default %s: %s" env_var default_value ;
      default_value

(** Find gsutil executable or return empty string if not found.

    @return Deferred string with gsutil path or empty string
*)
let find_gsutil () =
  Log.Global.info "Checking for gsutil availability" ;
  match Sys.getenv Constants.EnvVars.gsutil with
  | Some exe ->
      Log.Global.info "Using GSUTIL from environment: %s" exe ;
      return exe
  | None -> (
      Log.Global.info "GSUTIL not set, searching in PATH" ;
      match%bind run_command_capture "command -v gsutil || echo ''" with
      | Ok path ->
          let stripped_path = String.strip path in
          if String.is_empty stripped_path then
            Log.Global.info "gsutil not found"
          else Log.Global.info "Found gsutil at: %s" stripped_path ;
          return stripped_path
      | Error _ ->
          Log.Global.info "gsutil not found" ;
          return "" )

(** Check if the Mina daemon is currently running.

    Reads the lock file to get the PID and checks if process is alive.

    @return Deferred boolean indicating if daemon is running
*)
let is_daemon_running () =
  let lock_file = Constants.Paths.mina_lock_file in
  Log.Global.debug "Checking if daemon is running via lock file: %s" lock_file ;
  let%bind daemon_pid =
    run_command_capture (sprintf "cat %s 2>/dev/null || echo ''" lock_file)
  in
  match daemon_pid with
  | Ok pid_str ->
      let pid = String.strip pid_str in
      if String.is_empty pid then return false
      else (
        Log.Global.debug "Checking if daemon process %s is still running" pid ;
        match%map run_command (sprintf "kill -0 %s 2>/dev/null" pid) with
        | Ok () ->
            true
        | Error _ ->
            false )
  | Error _ ->
      return false
