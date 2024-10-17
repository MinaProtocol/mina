open Core
open Async

let config_dir = "mina_spun_test"

let genesis_dir = "mina_genesis_state"

let p2p_dir = "mina_test_libp2p_keypair"

let default_root_path = "/tmp"

module ConfigDirs = struct
  type t =
    { root_path : string
    ; conf : Filename.t
    ; genesis : Filename.t
    ; libp2p_keypair : Filename.t
    }

  let libp2p_keypair_folder t = String.concat [ t.libp2p_keypair; "/privkey" ]

  let create root_path =
    (* create empty config dir to avoid any issues with the default config dir *)
    let conf = Filename.temp_dir ~in_dir:root_path config_dir "" in
    let genesis = Filename.temp_dir ~in_dir:root_path genesis_dir "" in
    let libp2p_keypair = Filename.temp_dir ~in_dir:root_path p2p_dir "" in
    { root_path; conf; genesis; libp2p_keypair }

  let generate_keys t =
    let open Deferred.Let_syntax in
    let%map () =
      Init.Client.generate_libp2p_keypair_do (libp2p_keypair_folder t) ()
    in
    ()

  let dirs t = [ t.conf; t.genesis; t.libp2p_keypair ]

  let mina_log t = t.conf ^/ "mina.log"
end

module Config = struct
  type t =
    { port : int; dirs : ConfigDirs.t; mina_exe : string; clean_up : bool }

  let create port dirs mina_exe clean_up = { port; dirs; mina_exe; clean_up }

  let default port mina_path =
    let dirs = ConfigDirs.create default_root_path in
    create port dirs mina_path true
end
