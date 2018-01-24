open Core
open Async

let get_pods 
      container_count 
      containers_per_machine 
      external_tcp_ports 
      internal_tcp_ports 
      internal_udp_ports
  = 
  let start_pods nodes pods container_count containers_per_machine = 
    let available_slots = 
      List.map nodes ~f:(fun node -> 
        let containers = List.count pods ~f:(fun pod -> String.(pod.Kubernetes.Pod.hostname = node.Kubernetes.Node.hostname)) in
        (node, containers_per_machine - containers))
    in 
    let available_slots = List.concat (List.map available_slots ~f:(fun (node, count) -> List.init count ~f:(fun _ -> node))) in
    let available_slots_count = List.length available_slots in
    let new_containers_count = container_count - (List.length pods) in
    if new_containers_count > available_slots_count 
    then raise (Failure "not enough slots available")
    else 
      let new_containers = List.take available_slots container_count in
      let rand_char () = Char.of_int_exn (Char.to_int 'a' + Random.int 26) in
      let rand_name () = String.init 10 ~f:(fun _ -> rand_char ()) in
      Deferred.all_ignore
        (List.map new_containers ~f:(fun node -> 
           Kubernetes.run_pod 
             ("testbridge-" ^ (rand_name ())) 
             "localhost:5000/testbridge" 
             node.hostname  
             (List.concat [ external_tcp_ports; internal_tcp_ports ])
             internal_udp_ports
         ))
  in
  let nodes_needed = 
    Float.iround_up_exn
       ((float_of_int container_count) /. 
        (float_of_int containers_per_machine)) in
  let%bind nodes = Kubernetes.wait_for_nodes nodes_needed in
  let%bind all_pods = Kubernetes.get_pods () in
  let pods = List.filter all_pods ~f:(fun p -> p.status <> `Terminating) in
  (*printf "%s\n" (String.concat ~sep:", "  (List.map nodes ~f:(fun node -> 
    Sexp.to_string_hum ([%sexp_of: Kubernetes.Node.t] node))));
  printf "%s\n" (String.concat ~sep:", "  (List.map pods ~f:(fun pod -> 
    Sexp.to_string_hum ([%sexp_of: Kubernetes.Pod.t] pod))));*)

  let%bind () = 
    if container_count > List.length pods
    then 
      begin
        let%map () = start_pods nodes pods container_count containers_per_machine in
        printf "starting pods\n"
      end
    else return ()
  in
  let%map all_pods = Kubernetes.wait_for_pods container_count in
  let pods = List.take all_pods container_count in
  pods

module Rpcs = struct
  module Ping = struct
    type query = unit [@@deriving bin_io]
    type response = unit [@@deriving bin_io]

    (* TODO: Use stable types. *)
    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Ping" ~version:0
        ~bin_query ~bin_response
  end

  module Run = struct
    type query = String.t * String.t list [@@deriving bin_io]
    type response = String.t [@@deriving bin_io]

    (* TODO: Use stable types. *)
    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Run" ~version:0
        ~bin_query ~bin_response
  end

  module Init = struct
    type cmd = String.t * String.t list [@@deriving bin_io]
    type query = cmd * String.t [@@deriving bin_io]
    type response = String.t [@@deriving bin_io]

    (* TODO: Use stable types. *)
    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Init" ~version:0
        ~bin_query ~bin_response
  end
end


let create project_dir container_count containers_per_machine external_tcp_ports internal_tcp_ports internal_udp_ports = 
  let%bind pods = 
    get_pods 
      container_count 
      containers_per_machine 
      external_tcp_ports 
      internal_tcp_ports 
      internal_udp_ports in
  let testbridge_port = 8100 in
  let client_ports = external_tcp_ports in
  let%bind ports = Kubernetes.forward_ports pods (List.concat [ [ testbridge_port ]; client_ports ]) in
  let testbridge_ports = List.map ports ~f:(fun pod_ports -> (List.nth_exn pod_ports 0)) in
  let%bind tar_string = 
    Process.run_exn ~working_dir:project_dir ~prog:"tar" ~args:[ "czvf"; "-"; "." ] () 
  in
  printf "waiting for pods...\n";
  let%bind () = 
    Deferred.List.iter 
      ~how:`Parallel
      testbridge_ports
      ~f:(fun port -> 
           Kubernetes.call_retry
             Rpcs.Ping.rpc 
             port 
             () 
             ~retries:4
             ~wait:(sec 2.0)
           )
  in
  printf "starting clients...\n";
  let%map () = 
    Deferred.List.iter
      ~how:`Parallel
      testbridge_ports
      ~f:(fun port -> 
        let%map out =
          Kubernetes.call_exn
            Rpcs.Init.rpc 
            port 
            (("bash", [ "/app/testbridge-launch.sh"]), tar_string)
        in
        ())
        (*printf "got %s\n" out)*)
  in
  let client_ports = List.map ports ~f:(fun pod_ports -> (List.drop pod_ports 1)) in
  client_ports
;;
