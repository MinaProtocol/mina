open Core
open Async

module Rpcs = struct
  module Ping = struct
    type query = unit [@@deriving bin_io]
    type response = unit [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Ping" ~version:0
        ~bin_query ~bin_response
  end

  module Init = struct
    type query = 
      { start_prover: bool
      ; prover_port: int
      ; storage_location: string
      ; initial_peers: Host_and_port.t list
      ; should_mine: bool
      ; me: Host_and_port.t
      }
    [@@deriving bin_io, sexp]
    type response = unit [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Init" ~version:0
        ~bin_query ~bin_response
  end

  module Get_peers = struct
    type query = unit [@@deriving bin_io]
    type response = Host_and_port.t list Option.t [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Get_peers" ~version:0
        ~bin_query ~bin_response
  end
end

let rec zip3_exn xs ys zs =
  match (xs, ys, zs) with
  | ([], [], []) -> []
  | (x::xs, y::ys, z::zs) -> (x, y, z)::zip3_exn xs ys zs
  | _ -> failwith "lists not same length"

let main ports internal_tcp_ports internal_udp_ports = 
  let echo_ports = List.map ports ~f:(fun pod_ports -> List.nth_exn pod_ports 0) in
  let nanobit_ports = List.map internal_tcp_ports ~f:(fun pod_ports -> List.nth_exn pod_ports 0) in
  let nanobit_udp_ports = List.map internal_udp_ports ~f:(fun pod_ports -> List.nth_exn pod_ports 0) in
  printf "starting host: %s\n%s\n%s\n" 
    (Sexp.to_string_hum ([%sexp_of: int list list] ports))
    (Sexp.to_string_hum ([%sexp_of: Host_and_port.t list list] internal_tcp_ports))
    (Sexp.to_string_hum ([%sexp_of: Host_and_port.t list list] internal_udp_ports));
  printf "starting host: %s\n" (Sexp.to_string_hum ([%sexp_of: int list list] ports));
  printf "waiting for clients...\n";
  let%bind () = 
    Deferred.List.iter 
      ~how:`Parallel
      echo_ports
      ~f:(fun port -> 
           Testbridge.Kubernetes.call_retry
             Rpcs.Ping.rpc 
             port 
             () 
             ~retries:30
             ~wait:(sec 5.0)
           )
  in
  List.iteri (zip3_exn echo_ports nanobit_ports nanobit_udp_ports) ~f:(fun i (port, self_port, udp_port) -> 
    don't_wait_for begin
      let args = 
        if i = 0 
        then { Rpcs.Init.start_prover = true
             ; prover_port = 8002
             ; storage_location = "/app/block-storage"
             ; initial_peers = List.drop nanobit_udp_ports 1
             ; should_mine = false
             ; me = udp_port }
        else { Rpcs.Init.start_prover = true
             ; prover_port = 8002
             ; storage_location = "/app/block-storage"
             ; initial_peers = []
             ; should_mine = false
             ; me = udp_port }
      in
      printf "init: %s\n" 
        (Sexp.to_string_hum ([%sexp_of: Rpcs.Init.query] args));
      let%bind res = 
        Testbridge.Kubernetes.call_exn
          Rpcs.Init.rpc
          port
          args
      in
      printf "started!\n";
      let%bind () = after (sec 5.0) in
      let%map peers = 
        Testbridge.Kubernetes.call_exn
          Rpcs.Get_peers.rpc
          port
          ()
      in
      printf "peers: %s\n" 
        (Sexp.to_string_hum ([%sexp_of: Host_and_port.t list option] peers));
    end);
  Async.never ()
;;

let () =
  let open Command.Let_syntax in
  Command.async
    ~summary:"Current daemon"
    begin
      [%map_open
        let container_count =
          flag "container-count"
            ~doc:"number of container"
            (required int)
        and containers_per_machine =
          flag "containers-per-machine"
            ~doc:"containers per machine" (required int)
        and image_host =
          flag "image-host"
            ~doc:"location of docker repository" (required string)
        in
        fun () ->
          let open Deferred.Let_syntax in
          let%bind external_ports, internal_tcp_ports, internal_udp_ports = 
            Testbridge.Main.create 
              ~image_host
              ~project_dir:"../../../../../" 
              ~to_tar:[ "app/"
                      ; "lib/"
                      ; "swimlib.opam"
                      ; "nanobit_base.opam"
                      ; "linear_pipe.opam"
                      ; "testbridge.opam"
                      ; "ccc.opam"
                      ; "echo.opam"
                      ; "stdout.opam"
                      ; "lib/testbridge/tests/nanobit/testbridge-launch.sh" 
                      ]
              ~launch_cmd:("bash", [ "/app/lib/testbridge/tests/nanobit/testbridge-launch.sh"])
              ~pre_cmds:[ ("mv", [ "/app/_build"; "/testbridge/app_build" ]) ]
              ~post_cmds:[ ("mv", [ "/testbridge/app_build"; "/app/_build" ]) ]
              ~container_count:container_count 
              ~containers_per_machine:containers_per_machine 
              ~external_tcp_ports:[ 8010 ] 
              ~internal_tcp_ports:[ 8001 ] 
              ~internal_udp_ports:[ 8000 ] 
          in
          main external_ports internal_tcp_ports internal_udp_ports
      ]
    end
  |> Command.run


let () = never_returns (Scheduler.go ())
;;
