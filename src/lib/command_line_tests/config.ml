open Core
open Async

let config_dir = "mina_spun_test"

let genesis_dir = "mina_genesis_state"

let p2p_dir = "mina_test_libp2p_keypair"

let default_root_path = "/tmp"

(* executable location relative to src/default/lib/command_line_tests

   dune won't allow running it via "dune exec", because it's outside its
   workspace, so we invoke the executable directly

   the mina.exe executable must have been built before running the test
   here, else it will fail
*)
let default_mina_exe = "_build/default/src/app/cli/src/mina.exe"

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
  type t = { port : int; dirs : ConfigDirs.t; mina_exe : string }

  let create port dirs mina_exe = { port; dirs; mina_exe }

  let default port =
    let dirs = ConfigDirs.create default_root_path in
    { port; dirs; mina_exe = default_mina_exe }
end
