open Async
open Core
open Config
open Mina_cli

module MinaBootstrapper = struct
  type t =
    { config : Config.t
    ; client_delay : float
    ; retry_delay : float
    ; retry_attempts : int
    }

  let create config =
    { config; client_delay = 40.; retry_delay = 30.; retry_attempts = 5 }

  let get_args t working_dir =
    [ "daemon"
    ; "-seed"
    ; "--demo-mode"
    ; "-background"
    ; "-working-dir"
    ; working_dir
    ; "-client-port"
    ; sprintf "%d" t.config.port
    ; "-config-directory"
    ; t.config.dirs.conf
    ; "-genesis-ledger-dir"
    ; t.config.dirs.genesis
    ; "-current-protocol-version"
    ; "0.0.0"
    ; "-external-ip"
    ; "0.0.0.0"
    ; "-libp2p-keypair"
    ; ConfigDirs.libp2p_keypair_folder t.config.dirs
    ]

  let prepare t =
    let working_dir = Sys.getcwd () in
    let args = get_args t working_dir in
    Async.printf "Starting daemon inside %s\n" working_dir ;
    Async.printf "Starting command: %s %s\n" t.config.mina_exe
      (String.concat ~sep:" " args) ;
    return (t.config.mina_exe, args)

  let start t =
    let%bind prog, args = prepare t in
    Process.create ~prog ~args ()

  let wait_for_bootstrap t =
    let mina_cli = MinaCli.create t.config.port t.config.mina_exe in
    Async.printf "Waiting initial %d s. before connecting\n"
      (int_of_float t.client_delay) ;
    let%bind _ =
      Deferred.map (after @@ Time.Span.of_sec t.client_delay) ~f:Or_error.return
    in
    let rec go retries_remaining =
      match%bind MinaCli.daemon_status mina_cli with
      | Error _ when retries_remaining > 0 ->
          Async.printf "Daemon not responding.. retrying (%i/%i)\n"
            (t.retry_attempts - retries_remaining)
            t.retry_attempts ;
          let%bind () = after @@ Time.Span.of_sec t.retry_delay in
          go (retries_remaining - 1)
      | ret ->
          return ret
    in
    go t.retry_attempts
end
