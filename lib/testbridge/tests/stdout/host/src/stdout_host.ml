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

  module Echo = struct
    type query = String.t [@@deriving bin_io]
    type response = String.t [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Echo" ~version:0
        ~bin_query ~bin_response
  end
end

let main ports = 
  let echo_ports = List.map ports ~f:(fun pod_ports -> List.nth_exn pod_ports 0) in
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
             ~retries:4
             ~wait:(sec 2.0)
           )
  in
  printf "calling echo...\n";
  List.iter echo_ports ~f:(fun port -> 
    don't_wait_for begin
      let%map res = 
        Testbridge.Kubernetes.call_exn
          Rpcs.Echo.rpc
          port
          "hi1234"
      in
      printf "%s\n" res
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
              ~project_dir:"../client" 
              ~to_tar:[ "." ]
              ~pre_cmds:[]
              ~post_cmds:[]
              ~launch_cmd:("bash", [ "/app/testbridge-launch.sh"])
              ~container_count:container_count 
              ~containers_per_machine:containers_per_machine 
              ~external_tcp_ports:[ 8000 ] 
              ~internal_tcp_ports:[] 
              ~internal_udp_ports:[] 
          in
          main external_ports
      ]
    end
  |> Command.run


let () = never_returns (Scheduler.go ())
;;
