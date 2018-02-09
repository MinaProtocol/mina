open Core
open Async
open Nanobit_base
open Cli_common

let daemon =
  let open Command.Let_syntax in
  Command.async
    ~summary:"Current daemon"
    begin
      [%map_open
        let conf_dir =
          flag "config directory"
            ~doc:"Configuration directory"
            (optional file)
        and should_mine =
          flag "mine"
            ~doc:"Run the miner" (required bool)
        and port =
          flag "port"
            ~doc:"Server port for other to connect" (required int16)
        and ip =
          flag "ip"
            ~doc:"External IP address for others to connect" (optional string)
        and start_prover =
          flag "start-prover" no_arg
            ~doc:"Start a new prover process"
        and prover_port =
          flag "prover-port" (optional_with_default Prover.default_port int16)
            ~doc:"Port for prover to listen on" 
        in
        fun () ->
          let open Deferred.Let_syntax in
          let%bind home = Sys.home_directory () in
          let conf_dir =
            Option.value ~default:(home ^/ ".current-config") conf_dir
          in
          let%bind () = Unix.mkdir ~p:() conf_dir in
          let%bind initial_peers =
            let peers_path = conf_dir ^/ "peers" in
            match%bind Reader.load_sexp peers_path [%of_sexp: Host_and_port.t list] with
            | Ok ls -> return ls
            | Error e -> 
              begin
                let default_initial_peers = [] in
                let%map () = Writer.save_sexp peers_path ([%sexp_of: Host_and_port.t list] default_initial_peers) in
                []
              end
          in
          let%bind prover =
            if start_prover
            then Prover.create ~port:prover_port ~debug:() How_to_obtain_keys.Generate_both
            else Prover.connect { host = "0.0.0.0"; port = prover_port }
          in
          let%bind genesis_proof = Prover.genesis_proof prover >>| Or_error.ok_exn in
          let genesis_chain = { Blockchain.state = Blockchain.State.zero; proof = genesis_proof } in
          let%bind () = Main.assert_chain_verifies prover genesis_chain in
          let%bind ip =
            match ip with
            | None -> Find_ip.find ()
            | Some ip -> return ip
          in
          Main.main
            prover
            (conf_dir ^/ "storage")
            { Blockchain.state = Blockchain.State.zero; proof = genesis_proof }
            initial_peers 
            should_mine
            (Host_and_port.create ~host:ip ~port)
            ()
      ]
    end
;;

  let () = 
  Command.group ~summary:"Current"
    [ "daemon", daemon
    ; "prover", Prover.command
    ; "rpc", Main_rpc.command
    ]
  |> Command.run
;;

let () = never_returns (Scheduler.go ())
;;
