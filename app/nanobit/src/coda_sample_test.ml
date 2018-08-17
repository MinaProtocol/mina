open Core
open Async
open Nanobit_base
open Coda_main
open Spawner
open Coda_worker

let run =
  let open Command.Let_syntax in
  (* HACK: to run the dependency, Kademlia *)
  let%map_open program_dir =
    flag "program-directory" ~doc:"base directory of nanobit project "
      (optional file)
  and {host; executable_path} = Command_util.config_arguments in
  fun () ->
    let open Deferred.Let_syntax in
    let open Master in
    let%bind program_dir =
      Option.value_map program_dir ~default:(Unix.getcwd ()) ~f:return
    in
    let setup_peers log_dir peers =
      Writer.save
        (Filename.concat log_dir "peers")
        ~contents:([%sexp_of : Host_and_port.t list] peers |> Sexp.to_string)
    in
    let init_coda t ~config ~log_dir ~my_port ~peers ~gossip_port ~should_wait =
      let {Spawner.Config.host; id} = config in
      let%bind () = setup_peers log_dir peers in
      let%bind () =
        add t
          { Coda_worker.host
          ; my_port
          ; peers
          ; log_dir
          ; program_dir
          ; gossip_port
          ; should_wait }
          id ~config
      in
      Deferred.unit
    in
    let t = create () in
    let log_dir_1 = "/tmp/current_config_1"
    and log_dir_2 = "/tmp/current_config_2" in
    File_system.with_temp_dirs [log_dir_1; log_dir_2] ~f:(fun () ->
        let process1 = 1 and process2 = 2 in
        let config1 = {Spawner.Config.id= process1; host; executable_path}
        and config2 = {Spawner.Config.id= process2; host; executable_path} in
        let coda_gossip_port = 8000 in
        let coda_my_port = 3000 in
        let%bind () =
          init_coda t ~config:config1 ~log_dir:log_dir_1 ~my_port:coda_my_port
            ~peers:[] ~gossip_port:coda_gossip_port ~should_wait:false
        in
        let%bind () = Option.value_exn (run t process1) in
        let reader = new_states t in
        let%bind _, _ = Linear_pipe.read_exn reader in
        let expected_peers = [Host_and_port.create host coda_my_port] in
        let%bind () =
          init_coda t ~config:config2 ~log_dir:log_dir_2 ~my_port:coda_my_port
            ~peers:expected_peers ~gossip_port:(coda_gossip_port + 1)
            ~should_wait:true
        in
        let%bind () = Option.value_exn (run t process2) in
        let%map _, coda_2_peers = Linear_pipe.read_exn reader in
        assert (expected_peers = coda_2_peers) )

let name = "coda-sample-test"

let command =
  Command.async
    ~summary:
      "A test that shows how a coda instance can identify another instance as \
       it's peer"
    run
