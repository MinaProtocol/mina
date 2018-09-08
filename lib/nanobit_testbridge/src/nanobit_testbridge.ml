open Core
open Async

module Make (Consensus_mechanism : Consensus.Mechanism.S) = struct
  module Blockchain = Blockchain_snark.Blockchain.Make (Consensus_mechanism)

  let remove_nth xs n = List.concat [List.take xs n; List.drop xs (n + 1)]

  module Rpcs = struct
    module Ping = struct
      type query = unit [@@deriving bin_io]

      type response = unit [@@deriving bin_io]

      let rpc : (query, response) Rpc.Rpc.t =
        Rpc.Rpc.create ~name:"Ping" ~version:0 ~bin_query ~bin_response
    end

    module Main = struct
      type query =
        { start_prover: bool
        ; prover_port: int
        ; storage_location: string
        ; initial_peers: Host_and_port.t list
        ; should_mine: bool
        ; me: Host_and_port.t }
      [@@deriving bin_io, sexp]

      type response = unit [@@deriving bin_io]

      let rpc : (query, response) Rpc.Rpc.t =
        Rpc.Rpc.create ~name:"Main" ~version:0 ~bin_query ~bin_response
    end

    module Get_peers = struct
      type query = unit [@@deriving bin_io]

      type response = Host_and_port.t list Option.t [@@deriving bin_io]

      let rpc : (query, response) Rpc.Rpc.t =
        Rpc.Rpc.create ~name:"Get_peers" ~version:0 ~bin_query ~bin_response
    end

    module Get_strongest_blocks = struct
      type query = unit [@@deriving bin_io]

      type response = Blockchain.t [@@deriving bin_io]

      type error = unit [@@deriving bin_io]

      let rpc : (query, response, error) Rpc.Pipe_rpc.t =
        Rpc.Pipe_rpc.create ~name:"Get_strongest_blocks" ~version:0 ~bin_query
          ~bin_response ~bin_error ()
    end
  end

  module Nanobit = struct
    type t =
      { testbridge_client: Testbridge.Main.Client.t
      ; bridge_port: int
      ; membership_addr: Host_and_port.t }
    [@@deriving sexp]
  end

  let wait_up ?(secs= 120) nanobit =
    Testbridge.Kubernetes.call_retry Rpcs.Ping.rpc nanobit.Nanobit.bridge_port
      () ~retries:(secs / 3) ~wait:(sec 3.0)

  let make_args nanobit ?(should_mine= false) initial_peers =
    { Rpcs.Main.start_prover= false
    ; prover_port= 8002
    ; storage_location= "/app/block-storage"
    ; initial_peers
    ; should_mine
    ; me= nanobit.Nanobit.membership_addr }

  let get_peers nanobit =
    Testbridge.Kubernetes.call_exn Rpcs.Get_peers.rpc
      nanobit.Nanobit.bridge_port ()

  let get_strongest_blocks nanobit ~f =
    Testbridge.Kubernetes.call_pipe_exn Rpcs.Get_strongest_blocks.rpc
      nanobit.Nanobit.bridge_port () ~f:(fun (pipe, _id) -> f pipe )

  let main nanobit args =
    Testbridge.Kubernetes.call_exn Rpcs.Main.rpc nanobit.Nanobit.bridge_port
      args

  let make_nanobit client =
    { Nanobit.testbridge_client= client
    ; bridge_port=
        List.nth_exn client.Testbridge.Main.Client.exposed_tcp_ports 0
    ; membership_addr=
        List.nth_exn client.Testbridge.Main.Client.internal_udp_addrs 0 }

  let stop nanobit = Testbridge.Main.stop nanobit.Nanobit.testbridge_client

  let start nanobit =
    let%bind () = Testbridge.Main.start nanobit.Nanobit.testbridge_client in
    wait_up nanobit

  let run_main_fully_connected ?(should_mine= false) nanobits =
    let membership_addrs =
      List.map nanobits ~f:(fun nanobit -> nanobit.Nanobit.membership_addr)
    in
    (* These are the args that other people will use *)
    let next_args =
      List.mapi nanobits ~f:(fun i nanobit ->
          make_args ~should_mine nanobit (remove_nth membership_addrs i) )
    in
    match next_args with
    | [] -> return []
    | _first_args :: rest_args ->
        let initial_node_args =
          make_args ~should_mine (List.hd_exn nanobits) []
        in
        let full_args = initial_node_args :: rest_args in
        let%map () =
          Deferred.List.iter ~how:`Parallel (List.zip_exn nanobits full_args)
            ~f:(fun (nanobit, args) -> main nanobit args )
        in
        next_args

  let cmd main =
    let open Command.Let_syntax in
    Command.async ~summary:"Current daemon"
      (let%map_open container_count =
         flag "container-count" ~doc:"number of container" (required int)
       and containers_per_machine =
         flag "containers-per-machine" ~doc:"containers per machine"
           (required int)
       and image_host =
         flag "image-host" ~doc:"location of docker repository"
           (required string)
       in
       fun () ->
         let open Deferred.Let_syntax in
         let%bind clients =
           Testbridge.Main.create ~image_host ~project_dir:"../../../"
             ~to_tar:
               [ "app/"
               ; "lib/"
               ; "lib/nanobit_testbridge/testbridge-launch.sh"
               ; "snarky.opam"
               ; "linear_pipe.opam"
               ; "nanobit_testbridge.opam"
               ; "testbridge.opam"
               ; "ccc.opam"
               ; "logger.opam"
               ; "stdout.opam"
               ; "echo.opam"
               ; "nanobit_base.opam"
               ; "kademlia.opam"
               ; "distributed_dsl.opam" ]
             ~launch_cmd:
               ("bash", ["lib/nanobit_testbridge/testbridge-launch.sh"])
             ~pre_cmds:
               [ ("mv", ["/app/_build"; "/testbridge/app_build"])
                 (* We need to remove any nix artifacts BEFORE we untar that happen to be in this directory *)
               ; ("chmod", ["-R"; "+w"; "/app/app/kademlia-haskell"])
               ; ("rm", ["-rf"; "/app/app/kademlia-haskell/result"]) ]
             ~post_cmds:
               [ ("mv", ["/testbridge/app_build"; "/app/_build"])
                 (* We need to make sure we remove nix artifacts that may have been tarred, or else the build fails *)
               ; ("chmod", ["-R"; "+w"; "/app/app/kademlia-haskell"])
               ; ("rm", ["-rf"; "/app/app/kademlia-haskell/result"]) ]
             ~container_count ~containers_per_machine
             ~external_tcp_ports:[8010] ~internal_tcp_ports:[8001]
             ~internal_udp_ports:[8000]
         in
         let nanobits =
           List.map clients ~f:(fun client -> make_nanobit client)
         in
         let%bind () = Deferred.List.iter ~how:`Parallel nanobits ~f:wait_up in
         main nanobits)
    |> Command.run
end
