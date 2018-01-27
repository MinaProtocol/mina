open Core
open Async
open Yojson


module Node = struct
  type t =
    { ready : bool
    ; hostname: string
    }
  [@@deriving sexp]
end

module Pod = struct

  type status = [ `Running | `Pending | `Terminating ]
  [@@deriving sexp]

  type t =
    { container_name : string
    ; pod_name : string
    ; status : status
    ; hostname : string
    }
  [@@deriving sexp]
end

module Service = struct

  type protocol = [ `TCP | `UDP ]
  [@@deriving sexp]

  type t =
    { name : string
    ; node_port : int
    ; port : int
    ; protocol : protocol
    }
  [@@deriving sexp]
end

let get_nodes () = 
  let%map stdout = Process.run_exn ~prog:"kubectl" ~args:[ "get"; "nodes"; "-o"; "json" ] () in
  let json = Yojson.Basic.from_string stdout in
  let open Yojson.Basic.Util in
  let items = json |> member "items" |> to_list in
  List.map items ~f:(fun item -> 
    let hostname = 
      item |> member "metadata" |> member "labels" |> member "kubernetes.io/hostname" |> to_string 
    in
    let ready = 
      let conditions = item |> member "status" |> member "conditions" |> to_list in
      List.exists 
        conditions 
        ~f:(fun condition -> 
          let condition_type = condition |> member "type" |> to_string in
          String.(condition_type = "Ready"))
    in
    { Node.ready; hostname }
  )
;;

let wait_for_nodes nodes_needed = 
  let rec go () = 
    let%bind nodes = get_nodes () in
    let nodes_have = List.count nodes ~f:(fun n -> n.ready) in
    if nodes_have >= nodes_needed
    then return nodes
    else 
      let%bind () = (after (sec 1.))
      and () = return (printf "have %d / %d nodes\n" nodes_have nodes_needed) in
      go ()
  in
  go ()
;;

let get_pods () = 
  let%map stdout = Process.run_exn ~prog:"kubectl" ~args:[ "get"; "pods"; "-o"; "json" ] () in
  let json = Yojson.Basic.from_string stdout in
  let open Yojson.Basic.Util in
  let items = json |> member "items" |> to_list in
  let pods = 
    List.map items ~f:(fun item ->  
      let containers = item |> member "spec" |> member "containers" |> to_list in
      let container = List.nth_exn containers 0 in
      let deleting = item |> member "metadata" |> member "deletionTimestamp" |> to_string_option in
      let phase = 
        if deleting <> None
        then `Terminating
        else 
          match (item |> member "status" |> member "phase" |> to_string) with
          | "Running" -> `Running
          | "Pending" -> `Pending
          | "Terminating" -> `Terminating
          | s -> failwith ("Unknown pod phase " ^ s)
      in
      let container_name = container |> member "name" |> to_string in
      let pod_name = item |> member "metadata" |> member "name" |> to_string in
      let hostname = item |> member "spec" |> member "nodeName" |> to_string in
      { Pod.container_name; Pod.pod_name; status = phase; hostname })
  in
  pods

let run_pod ~pod_name ~pod_image ~node_hostname ~tcp_ports ~udp_ports = 
  let wrap_assoc name json = (`Assoc [ (name, json) ] ) in
  let wrap_assocs names json = 
    List.fold 
      ~init:json 
      (List.rev names) 
      ~f:(fun json name -> wrap_assoc name json) in
  let pod_overrides = 
    let tcp_ports_json = 
      List.map tcp_ports ~f:(fun port -> 
          `Assoc [ ("containerPort", `Int port)
                 ; ("protocol", `String "TCP")
                 ])
    in
    let udp_ports_json = 
      List.map udp_ports ~f:(fun port -> 
          `Assoc [ ("containerPort", `Int port)
                 ; ("protocol", `String "UDP")
                 ])
    in
    let ports_json = List.concat [ udp_ports_json; tcp_ports_json ]
    in
    let container_json = 
      `Assoc [ ("image", `String pod_image)
             ; ("name", `String pod_name)
             ; ("ports", `List ports_json)
             ]
    in
    let json = 
      wrap_assocs 
        [ "spec"; "template"; "spec"; ] 
        (`Assoc 
           [ ("containers", (`List [ container_json ]))
           ; ("nodeSelector", wrap_assoc "kubernetes.io/hostname" (`String node_hostname))
         ])
    in
    json |> to_string
  in
  let prog = "kubectl" in
  (*printf "%s\n" pod_overrides;*)
  let args = [ "run"; pod_name; "--image=" ^ pod_image; "--overrides=" ^ pod_overrides ]  in
  let%bind () = Deferred.ignore (Process.run_exn ~prog ~args ()) in
  let args = [ "expose"; "deployment"; pod_name; "--type=NodePort" ]  in
  Deferred.ignore (Process.run_exn ~prog ~args ())

let wait_for_pods pods_needed = 
  let rec go () = 
    let%bind pods = get_pods () in
    let pods_have = List.count pods ~f:(fun n -> n.status = `Running) in
    if pods_have >= pods_needed
    then return pods
    else 
      let%bind () = (after (sec 1.))
      and () = return (printf "have %d / %d pods\n" pods_have pods_needed) in
      go ()
  in
  go ()
;;

let get_services pods =
  let%map stdout = Process.run_exn ~prog:"kubectl" ~args:[ "get"; "services"; "-o"; "json" ] () in
  let json = Yojson.Basic.from_string stdout in
  let open Yojson.Basic.Util in
  let items = json |> member "items" |> to_list in
  let pod_items =
    List.map pods ~f:(fun pod -> 
      List.find_exn items ~f:(fun item -> 
        let name = item |> member "metadata" |> member "name" |> to_string in
        name = pod.Pod.container_name))
  in
  let pod_specs = 
    List.map pod_items ~f:(fun item -> item |> member "spec")
  in
  List.map pod_specs ~f:(fun spec -> 
    let services = 
      List.map 
        (spec |> member "ports" |> to_list)
        ~f:(fun port_spec -> 
          let name = port_spec |> member "name" |> to_string in
          let node_port = port_spec |> member "nodePort" |> to_int in
          let port = port_spec |> member "port" |> to_int in
          let protocol = 
            (port_spec |> member "protocol" |> to_string)
            |> function 
            | "TCP" -> `TCP
            | "UDP" -> `UDP
            | s -> failwith ("Unknown protocol " ^ s)
          in
          { Service.name; node_port; port; protocol })
    in
    let ip = spec |> member "clusterIP" |> to_string in
    (services, ip))

let get_internal_ports pods ports =
  let%map pod_services = get_services pods in
  let pod_internal_ports =
    List.map pod_services ~f:(fun (services, ip) -> 
      List.map ports ~f:(fun port -> 
        let service = 
          List.find_exn
            services
            ~f:(fun service -> service.port = port)
        in
        Host_and_port.create ~host:ip ~port:service.port))
  in
  pod_internal_ports

let forward_ports pods ports = 
  let prog = "kubectl" in
  Deferred.List.map pods ~f:(fun pod -> 
    Deferred.List.map ports ~f:(fun port -> 
      let args = [ "port-forward"; pod.Pod.pod_name; "0" ^ ":" ^ (Int.to_string port) ] in
      let%bind process = Process.create_exn ~prog ~args () in
      let stdout = Process.stdout process in
      let%map line = 
        match%map (Reader.read_line stdout) with
        | `Ok l -> l
        | `Eof -> failwith "no line returned"
      in
      let hostport_token = List.nth_exn (String.split line ~on:' ') 2 in
      let port_token = List.nth_exn (String.split hostport_token ~on:':') 1 in
      let port = Int.of_string port_token in
      port))

let call rpc port query = 
  Tcp.with_connection
    (Tcp.Where_to_connect.of_host_and_port (Host_and_port.of_string ("127.0.0.1:" ^ (Int.to_string port))))
    ~timeout:(Time.Span.of_sec 2.)
    (fun _ r w ->
       match%bind Rpc.Connection.create r w ~connection_state:(fun _ -> ()) with
       | Error exn -> return (Or_error.of_exn exn)
       | Ok conn -> Rpc.Rpc.dispatch rpc conn query)

let call_exn rpc port query = 
  let%map res = call rpc port query
  in
  match res with
  | Ok msg -> msg
  | Error e -> failwith (Error.to_string_hum e)


let call_retry rpc port query ~retries ~wait = 
  let rec go remaining_tries = 
    let%bind res = call rpc port query
    in
    match res with
    | Ok msg -> return msg
    | Error e -> 
      if remaining_tries > 0
      then 
        let%bind () = after wait in
        go (remaining_tries - 1)
      else 
        failwith (Error.to_string_hum e)
  in
  go retries
