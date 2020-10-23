(* Copied from Base.List *)

let group l ~break =
  let hd_exn = List.hd in
  let fold t ~init ~f = List.fold_left f init t in
  let rev_map t ~f = List.rev_map f t in
  let rev = List.rev in
  let groups =
    fold l ~init:[] ~f:(fun acc x ->
      match acc with
      | [] -> [[x]]
      | current_group :: tl ->
        if break (hd_exn current_group) x then
          [x] :: current_group :: tl  (* start new group *)
        else
          (x :: current_group) :: tl) (* extend current group *)
  in
  match groups with
  | [] -> []
  | l -> rev_map l ~f:rev

module Node_network_info = struct
  type t =
    { local_ip : string
    ; external_ip : string
    ; peer_ips : string list
    ; name: string
    }
  [@@deriving yojson]
end 

let read_ips (s : string) : Node_network_info.t list =
  String.split_on_char '\n' s
  |> group ~break:(fun x _ -> x = "")
  |> Core.List.filter_map ~f:(function
      |  name :: local_ip :: external_ip :: peers :: _ ->
        let peer_ips =
          String.split_on_char ' ' peers 
          |> List.map (fun x ->
              match String.split_on_char ':' x with
              | [ ip; _port ] -> ip 
              | _ -> assert false
            )
        in
        Some { Node_network_info.name; local_ip; external_ip; peer_ips }
      | xs -> 
        Core.(eprintf !"%{sexp:string list}" xs );
        None )


module String_map = Map.Make(String)

module Block_produced = struct
  type t = {state_hash: string}
end 

module Block_received = struct
  type t = 
    { state_hash : string
    ; sender_ip: [ `Local of string | `External of string ] }
end 

module Event = struct
  type t =
    [ `Produced of Block_produced.t
    | `Received of Block_received.t ]

  let state_hash : t -> string = function
    | `Produced { state_hash } -> state_hash
    | `Received { state_hash; _ } -> state_hash
end 

let black = "rgb(0,0,0)"

let color_hash s =
  let n = Hashtbl.hash s in
  let r = n land 255 in
  let g = (n lsr 8) land 255 in
  let b = (n lsr 16) land 255 in
  Printf.sprintf "rgb(%d,%d,%d)" r g b

let hashtbl_of_alist xs =
    let t = Hashtbl.create 1024 in
    List.iter (fun (k, v) ->
        Hashtbl.add t k v )
      xs ;
    t

let to_json_for_vis
    (events : 
       ([`State_hash of string] * ( [ `Node_name of string ] * Block_received.t ) list) list )
    (network : Node_network_info.t list )
  : Yojson.Safe.t
  =
  let _by_name =
    hashtbl_of_alist
      (List.map 
         (fun x -> (x.Node_network_info.name, x))
         network )
  in 
  let by_local_ip =
    hashtbl_of_alist
      (List.map 
         (fun x -> (x.Node_network_info.local_ip, x))
         network )
  in 
  let by_external_ip =
    hashtbl_of_alist
      (List.map 
         (fun x -> (x.Node_network_info.external_ip, x))
         network )
  in 
  let (network_nodes, network_edges) =
    let nodes : Yojson.Safe.t =
      `List (
      List.map (fun (node : Node_network_info.t)  ->
        `Assoc
          [ ("id", `String node.name)
          ; ("label",`String  node.name)
          ]
        )
        network )
    in 
    let edges : Yojson.Safe.t =
      `List (
      List.map (fun (node : Node_network_info.t) ->
          Core.List.filter_map ~f:(fun peer_local_ip ->
                let open Core.Option.Let_syntax in
              let%map peer =
                match Hashtbl.find_opt by_local_ip peer_local_ip with
                | Some peer -> Some peer
                | None -> 
                  match Hashtbl.find_opt by_external_ip peer_local_ip with
                  | Some peer -> Some peer
                  | None ->
                    Core.(
                      eprintf !"warning couldn't find %s\n" peer_local_ip
                    ) ;
                    None
              in 
              `Assoc
              [ ("from", `String node.name)
              ; ("to", `String peer.name )
              ; ("color", `String black)
              ]
              )
            node.peer_ips )
        network
      |> List.concat )
    in
    (nodes, edges)
  in
  let propagation_graphs =
    let xs =
      List.map
        (fun (`State_hash state_hash, events) ->
          let edges =
            List.map (fun (`Node_name node, e) ->
                match e with
                | { Block_received.sender_ip; state_hash=_ } ->
                  let sender =
                    match sender_ip with
                    | `Local ip -> Hashtbl.find by_local_ip ip
                    | `External ip -> Hashtbl.find by_external_ip ip
                  in
                  `Assoc 
                    [ ("from", `String sender.name)
                    ; ("to", `String node)
                    ; ("arrows", `String "to")
                    ; ("color", `String (color_hash state_hash) )
                    ]
              )
              events
          in
          (state_hash, `List edges)
        )
        events
    in
    `Assoc xs
  in
  `Assoc
    [ ("nodes", network_nodes)
    ; ("edges", network_edges)
    ; ("edges_by_state_hash", propagation_graphs)
    ]

module Events = struct
  module Instant = struct
    type t =
      { time: string
      ; podRealName: string
      }
    [@@deriving yojson]
  end 

  module Instant_with_sender = struct
    type t =
      { time: string
      ; podRealName: string
      ; sender: string
      }
    [@@deriving yojson]
  end 

  module Event = struct
    type t =
      { stateHash: string
      ; produced: Instant.t
      ; received: Instant_with_sender.t list
      }
    [@@deriving yojson]
  end 

  type t = Event.t list
  [@@deriving yojson]
end 

open Core

let () =
  let network, events = 
    Sys.argv.(1), Sys.argv.(2)
  in
  let network = read_ips (In_channel.read_all network) in
  (* print_endline @@ Yojson.Safe.pretty_to_string @@ `List (List.map network ~f:Node_network_info.to_yojson) ; *)
  let events = 
    match Events.of_yojson (Yojson.Safe.from_file events) with
    | Ok x -> x
    | Error e -> failwith e
  in 
  let events =
    List.map events ~f:(fun { stateHash; produced=_; received } ->
        (`State_hash stateHash, 
        List.map received ~f:(fun { time=_; podRealName; sender } ->
            ( `Node_name podRealName, { Block_received.state_hash=stateHash
                                      ; sender_ip= `External sender } ) ) ) )
  in
  to_json_for_vis events network
  |> Yojson.Safe.to_file "graph.json"
