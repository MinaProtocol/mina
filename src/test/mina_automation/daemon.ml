(**
Module to run daemon process.
*)
open Core

open Async

module Paths = struct
  let dune_name = "src/app/cli/src/mina.exe"

  let official_name = "mina"
end

module Executor = Executor.Make (Paths)

type t = Executor.t

let logger = Logger.create ()

(** 
  Module [Client] provides functions to interact with a Mina daemon.
*)
module Client = struct
  type t = { port : int; executor : Executor.t }

  let create ?(port = 3085) ?(executor = Executor.AutoDetect) () =
    { port; executor }

  (** [stop_daemon t] stops the daemon running on the specified port.
    @param t The daemon instance containing the executor and port information.
    @return Unit. Executes the command to stop the daemon using the executor.
  *)
  let stop_daemon t =
    Executor.run t.executor
      ~args:[ "client"; "stop-daemon"; "-daemon-port"; sprintf "%d" t.port ]
      ()

  (** [daemon_status t] retrieves the status of the daemon running on the specified port.
    It executes the command `client status -daemon-port <port>` using the provided executor.
    
    @param t The daemon instance containing the executor and port information.
    @return The result of the executor run, which may be ignored if the command fails.
  *)
  let daemon_status t =
    Executor.run t.executor
      ~args:[ "client"; "status"; "-daemon-port"; sprintf "%d" t.port ]
      ~ignore_failure:true ()


  (** [wait_for_bootstrap t ?client_delay ?retry_delay ?retry_attempts ()] waits for the daemon to bootstrap.
    @param t The daemon instance containing the executor and port information.
    @param client_delay The delay before connecting to the daemon.
    @param retry_delay The delay between retries.
    @param retry_attempts The number of retries.
    @return A deferred result indicating the success or failure of the operation. 
  *)
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

  let default ?dirs =
    { port = 3085
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

(** 
  Module [Process] provides functions to interact with a Mina daemon process.
*)
module Process = struct
  type t = { process : Process.t; config : Config.t; client : Client.t }

  (** [force_kill t] sends a kill signal to the process associated with [t] and waits for the process to terminate.
    @param t The daemon instance containing the process to be killed.
    @return A deferred result indicating the success or failure of the operation.
  *)
  let force_kill t =
    Utils.force_kill t.process
  
end

let archive_blocks t ~archive_address ~(format : Archive_blocks.format) blocks =
  Executor.run t
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

let default = Executor.default

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

  [%log debug] "Starting daemon" ;

  let%bind process = Executor.run_in_background t ~args () in

  let mina_process : Process.t =
    { config; process; client = Client.create ~port:config.port ~executor:t () }
  in
  Deferred.return mina_process
