(**
Module to run archive_blocks utility for the given list of block files and an archive PostgreSQL database.
*)
open Executor

open Core
open Async

type t = { dune_name : String.t; official_name : String.t; context : context }

let dune_name = "src/app/cli/src/mina.exe"

let official_name = "mina"

let of_context context = { context; dune_name; official_name }

module Client = struct
  type t = { port : int; executor : Executor.t }

  let create ~port (executor : Executor.t) = { port; executor }

  let stop_daemon t =
    Executor.run t.executor
      ~args:[ "client"; "stop-daemon"; "-daemon-port"; sprintf "%d" t.port ]
      ()

  let daemon_status t =
    Executor.run t.executor
      ~args:[ "client"; "status"; "-daemon-port"; sprintf "%d" t.port ]
      ~ignore_failure:true ()

  let wait_for_bootstrap t ?(client_delay = 40.) ?(retry_delay = 60.)
      ?(retry_attempts = 10) () =
    Async.printf "Waiting initial %d s. before connecting\n"
      (int_of_float client_delay) ;
    let%bind _ =
      Deferred.map (after @@ Time.Span.of_sec client_delay) ~f:Or_error.return
    in
    let rec go retries_remaining =
      let%bind output = daemon_status t in
      Async.printf "%s" output ;
      if String.is_substring output ~substring:"Synced" then
        Deferred.Or_error.ok_unit
      else if retries_remaining > 0 then (
        Async.printf "Daemon not responding.. retrying (%i/%i)\n"
          (retry_attempts - retries_remaining)
          retry_attempts ;
        let%bind () = after @@ Time.Span.of_sec retry_delay in
        go (retries_remaining - 1) )
      else Deferred.Or_error.error_string output
    in
    go retry_attempts
end

module Config = struct
  module ConfigDirs = struct
    type t =
      { root_path : string
      ; conf : Filename.t
      ; genesis : Filename.t
      ; libp2p_keypair : Filename.t
      }

    let libp2p_keypair_folder t = String.concat [ t.libp2p_keypair; "/privkey" ]

    let create ?(root_path = "/tmp") ?(config_dir = "mina_spun_test")
        ?(genesis_dir = "mina_genesis_state")
        ?(p2p_dir = "mina_test_libp2p_keypair") () =
      (* create empty config dir to avoid any issues with the default config dir *)
      let conf = Filename.temp_dir ~in_dir:root_path config_dir "" in
      let genesis = Filename.temp_dir ~in_dir:root_path genesis_dir "" in
      let libp2p_keypair = Filename.temp_dir ~in_dir:root_path p2p_dir "" in
      { root_path; conf; genesis; libp2p_keypair }

    let dirs t = [ t.conf; t.genesis; t.libp2p_keypair ]

    let mina_log t = t.conf ^/ "mina.log"
  end

  type t = { port : int; dirs : ConfigDirs.t }

  let create ?dirs port =
    { port
    ; dirs = (match dirs with Some dirs -> dirs | None -> ConfigDirs.create ())
    }

  let libp2p_keypair_folder t = ConfigDirs.libp2p_keypair_folder t.dirs

  let generate_keys t =
    let open Deferred.Let_syntax in
    let%map () =
      Init.Client.generate_libp2p_keypair_do (libp2p_keypair_folder t) ()
    in
    ()
end

module DaemonProcess = struct
  type t = { process : Process.t; config : Config.t; client : Client.t }

  let force_kill t =
    Process.send_signal t.process Core.Signal.kill ;
    Deferred.map (Process.wait t.process) ~f:Or_error.return
end

let to_executor t =
  Executor.of_context ~context:t.context ~dune_name ~official_name

let to_async_executor t =
  Async_executor.of_context
    ~context:
      ( match t.context with
      | Debian ->
          Async_executor.Debian
      | Local ->
          Local
      | Dune ->
          Dune
      | Docker _ ->
          failwith "cannot use docker executor in async"
      | AutoDetect ->
          AutoDetect )
    ~dune_name ~official_name

let archive_blocks t ~archive_address ~(format : Archive_blocks.format) blocks =
  to_executor t
  |> Executor.run
       ~args:
         ( [ "advanced"
           ; "archive-blocks"
           ; "--archive-addres"
           ; string_of_int archive_address
           ; "-" ^ Archive_blocks.format_to_string format
           ]
         @ blocks )

let dispatch_blocks t ~archive_address ~(format : Archive_blocks.format)
    ?(sleep = 5) blocks =
  Deferred.List.iter blocks ~f:(fun block ->
      Core.Unix.sleep sleep ;
      archive_blocks t ~archive_address ~format [ block ] () >>| ignore )

let client t ~(config : Config.t) = Client.create ~port:config.port t

let start t (config : Config.t) =
  let args =
    [ "daemon"
    ; "-seed"
    ; "--demo-mode"
    ; "-background"
    ; "-working-dir"
    ; "."
    ; "-client-port"
    ; sprintf "%d" config.port
    ; "-config-directory"
    ; config.dirs.conf
    ; "-genesis-ledger-dir"
    ; config.dirs.genesis
    ; "-external-ip"
    ; "0.0.0.0"
    ; "-libp2p-keypair"
    ; Config.libp2p_keypair_folder config
    ]
  in
  let executor = to_async_executor t in
  let%bind process = Async_executor.run executor ~args () in
  let%bind prog = Async_executor.path executor in

  Async.printf "Starting daemon inside %s\n" "." ;
  Async.printf "Starting command: %s %s\n" prog (String.concat ~sep:" " args) ;

  let mina_process : DaemonProcess.t =
    { config; process; client = client (to_executor t) ~config }
  in
  Deferred.return mina_process
