open Core
open Async

let () = Random.self_init ()
;;

let rand_name () = 
  let rand_char () = Char.of_int_exn (Char.to_int 'a' + Random.int 26) in
  String.init 10 ~f:(fun _ -> rand_char ())
;;

module Rpcs = struct
  module Ping = struct
    type query = unit [@@deriving bin_io]
    type response = unit [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Ping" ~version:0
        ~bin_query ~bin_response
  end

  module Fetch = struct
    type query = Host_and_port.Stable.V1.t [@@deriving bin_io]
    type response = String.t [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Fetch" ~version:0
        ~bin_query ~bin_response
  end

  module Get = struct
    type query = unit [@@deriving bin_io]
    type response = String.t [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Get" ~version:0
        ~bin_query ~bin_response
  end

  module Set = struct
    type query = String.t [@@deriving bin_io]
    type response = unit [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Set" ~version:0
        ~bin_query ~bin_response
  end
end

let main ports internal_ports = 
  let echo_ports = List.map ports ~f:(fun pod_ports -> List.nth_exn pod_ports 0) in
  let call_ports = List.map internal_ports ~f:(fun pod_ports -> List.nth_exn pod_ports 0) in
  printf "6-starting host: %s\n%s\n" 
    (Sexp.to_string_hum ([%sexp_of: int list list] ports))
    (Sexp.to_string_hum ([%sexp_of: Host_and_port.t list list] internal_ports));
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
  let%bind () = 
    Deferred.List.all_unit (
      List.mapi echo_ports ~f:(fun i port -> 
        let id = rand_name () in
        printf "setting %d to %s...\n" port id;
        Testbridge.Kubernetes.call_exn
          Rpcs.Set.rpc
          port
          ("value-" ^ (Int.to_string i) ^ "-"^ id)))
  in
  let%bind fetch_results = 
    Deferred.List.map ~how:`Parallel (List.zip_exn echo_ports (List.rev call_ports)) ~f:(fun (port, call_port) -> 
      Testbridge.Kubernetes.call_exn
        Rpcs.Fetch.rpc
        port
        call_port)
  in
  printf "got fetch_results: %s\n" (Sexp.to_string_hum ([%sexp_of: string list] fetch_results));
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
        in
        fun () ->
          let open Deferred.Let_syntax in
          let%bind external_ports, internal_ports = 
            Testbridge.Main.create 
              ~project_dir:"../client" 
              ~container_count:container_count 
              ~containers_per_machine:containers_per_machine 
              ~external_tcp_ports:[ 8000 ] 
              ~internal_tcp_ports:[ 8001 ] 
              ~internal_udp_ports:[] 
          in
          main external_ports internal_ports
      ]
    end
  |> Command.run


let () = never_returns (Scheduler.go ())
;;

