open Core
open Async

let remove_nth xs n = List.concat [ List.take xs n; List.drop xs (n+1) ]

module Rpcs = struct
  module Ping = struct
    type query = unit [@@deriving bin_io]
    type response = unit [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Ping" ~version:0
        ~bin_query ~bin_response
  end

  module Get_cycles = struct
    type query = int * int [@@deriving bin_io]
    type response = (int * string) list [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Get_cycles" ~version:0
        ~bin_query ~bin_response
  end
end

module Node = struct
  type t =
    { testbridge_client: Testbridge.Main.Client.t
    ; bridge_port: int
    }
  [@@deriving sexp]
end

let wait_up ?(secs=120) node =
  Testbridge.Kubernetes.call_retry
    Rpcs.Ping.rpc 
    node.Node.bridge_port
    () 
    ~retries:(secs / 3)
    ~wait:(sec 3.0)
;;

let get_cycles node low high =
  Testbridge.Kubernetes.call_exn
    Rpcs.Get_cycles.rpc
    node.Node.bridge_port
    (low, high)
;;

let make_node client =
  { Node.testbridge_client = client
  ; bridge_port = List.nth_exn client.Testbridge.Main.Client.exposed_tcp_ports 0
  }
;;

let cmd main = 
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
          let%bind clients = 
            Testbridge.Main.create 
              ~image_host
              ~project_dir:"../../../" 
              ~to_tar:[ "app/mnt_cycle_search"
                      ; "lib/mnt_cycle_search_testbridge/testbridge-launch.sh"
                      ; "lib/mnt_cycle_search_testbridge/search.sh"
                      ; "lib/mnt_cycle_search_testbridge/search.py"
                      ; "sage.nix"
                      ; "lib/logger/"
                      ; "logger.opam"
                      ; "mnt_cycle_search_testbridge.opam"
                      ; "mnt_cycle_search_testbridge_searcher.opam"
                      ]
              ~launch_cmd:("bash", [ "lib/mnt_cycle_search_testbridge/testbridge-launch.sh"])
              ~pre_cmds: []
              ~post_cmds: []
              ~container_count:container_count 
              ~containers_per_machine:containers_per_machine 
              ~external_tcp_ports:[ 8010 ] 
              ~internal_tcp_ports:[] 
              ~internal_udp_ports:[] 
          in
          let nodes = List.map clients ~f:(fun client -> make_node client) in
          let%bind () = Deferred.List.iter ~how:`Parallel nodes ~f:wait_up in
          main nodes
      ]
    end
  |> Command.run

