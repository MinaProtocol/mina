open Core
open Async
open Nanobit_base
open Coda_main
open Spawner
open Coda_worker

module Coda_process_wrapper = struct
  type t = unit

  let command f =
    let open Command.Let_syntax in
    (* HACK: to run the dependency, Kademlia *)
    let%map_open program_dir =
      flag "program-directory" ~doc:"base directory of nanobit project "
        (optional file)
    and {host; executable_path} = Command_util.config_arguments in
    fun () -> f program_dir host executable_path

  (* TODO this only wraps a single process, should be able to wrap multiple processes *)
  let make_master program_dir host executable_path f =
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
    let log_dir_1 = "/tmp/current_config_1" in
    File_system.with_temp_dirs [log_dir_1] ~f:(fun () ->
        let process1 = 1 in
        let config1 = {Spawner.Config.id= process1; host; executable_path} in
        let coda_gossip_port = 8000 in
        let coda_my_port = 3000 in
        let%bind () =
          init_coda t ~config:config1 ~log_dir:log_dir_1 ~my_port:coda_my_port
            ~peers:[] ~gossip_port:coda_gossip_port ~should_wait:false
        in
        let%bind () = Option.value_exn (run t process1) in
        Print.printf "created!\n" ; f t )
end
