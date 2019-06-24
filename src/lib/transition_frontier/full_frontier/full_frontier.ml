open Core_kernel
open Coda_base
open Coda_state

module Make (Inputs : Inputs.S) = struct
  open Inputs

  (* NOTE: is Consensus_mechanism.select preferable over distance? *)

  let max_length = max_length

  module Breadcrumb = Breadcrumb.Make (Inputs)

  module Diff = Diff.Make (struct
    include Inputs
    module Breadcrumb = Breadcrumb
  end)

  module Hash = Frontier_hash.Make (struct
    include Inputs
    module Breadcrumb = Breadcrumb
    module Diff = Diff
  end)

  module Node = struct
    type t =
      { breadcrumb: Breadcrumb.t
      ; successor_hashes: State_hash.t list
      ; length: int }
    [@@deriving sexp, fields]

    type display =
      { length: int
      ; state_hash: string
      ; blockchain_state: Blockchain_state.display
      ; consensus_state: Consensus.Data.Consensus_state.display }
    [@@deriving yojson]

    let equal node1 node2 = Breadcrumb.equal node1.breadcrumb node2.breadcrumb

    let hash node = Breadcrumb.hash node.breadcrumb

    let compare node1 node2 =
      Breadcrumb.compare node1.breadcrumb node2.breadcrumb

    let name t = Breadcrumb.name t.breadcrumb

    let display t =
      let {Breadcrumb.state_hash; consensus_state; blockchain_state; _} =
        Breadcrumb.display t.breadcrumb
      in
      {state_hash; blockchain_state; length= t.length; consensus_state}
  end

  let breadcrumb_of_node {Node.breadcrumb; _} = breadcrumb

  (* Invariant: The path from the root to the tip inclusively, will be max_length *)
  type t =
    { root_snarked_ledger: Ledger.Db.t
    ; mutable root: State_hash.t
    ; mutable best_tip: State_hash.t
    ; logger: Logger.t
    ; table: Node.t State_hash.Table.t
    ; consensus_local_state: Consensus.Data.Local_state.t }

  let create ~logger
      ~(root_transition :
         (External_transition.Validated.t, State_hash.t) With_hash.t)
      ~root_snarked_ledger ~root_staged_ledger ~consensus_local_state =
    let root_hash = With_hash.hash root_transition in
    let root_protocol_state =
      External_transition.Validated.protocol_state
        (With_hash.data root_transition)
    in
    let root_blockchain_state =
      Protocol_state.blockchain_state root_protocol_state
    in
    let root_blockchain_state_ledger_hash =
      Blockchain_state.snarked_ledger_hash root_blockchain_state
    in
    assert (
      Ledger_hash.equal
        (Ledger.Db.merkle_root root_snarked_ledger)
        (Frozen_ledger_hash.to_ledger_hash root_blockchain_state_ledger_hash)
    ) ;
    let root_breadcrumb = Breadcrumb.create root_transition root_staged_ledger in
    let root_node =
      {Node.breadcrumb= root_breadcrumb; successor_hashes= []; length= 0}
    in
    let table = State_hash.Table.of_alist_exn [(root_hash, root_node)] in
    { logger
    ; root_snarked_ledger
    ; root= root_hash
    ; best_tip= root_hash
    ; table
    ; consensus_local_state }

  let consensus_local_state {consensus_local_state; _} = consensus_local_state

  let all_breadcrumbs t =
    List.map (Hashtbl.data t.table) ~f:(fun {breadcrumb; _} -> breadcrumb)

  let find t hash =
    let open Option.Let_syntax in
    let%map node = Hashtbl.find t.table hash in
    node.breadcrumb

  let find_exn t hash =
    let node = Hashtbl.find_exn t.table hash in
    node.breadcrumb

  let equal t1 t2 =
    let sort_breadcrumbs = List.sort ~compare:Breadcrumb.compare in
    let equal_breadcrumb breadcrumb1 breadcrumb2 =
      let open Breadcrumb in
      let open Option.Let_syntax in
      let get_successor_nodes frontier breadcrumb =
        let%map node = Hashtbl.find frontier.table @@ state_hash breadcrumb in
        Node.successor_hashes node
      in
      equal breadcrumb1 breadcrumb2
      && State_hash.equal (parent_hash breadcrumb1) (parent_hash breadcrumb2)
      && (let%bind successors1 = get_successor_nodes t1 breadcrumb1 in
          let%map successors2 = get_successor_nodes t2 breadcrumb2 in
          List.equal State_hash.equal
            (successors1 |> List.sort ~compare:State_hash.compare)
            (successors2 |> List.sort ~compare:State_hash.compare))
         |> Option.value_map ~default:false ~f:Fn.id
    in
    List.equal equal_breadcrumb
      (all_breadcrumbs t1 |> sort_breadcrumbs)
      (all_breadcrumbs t2 |> sort_breadcrumbs)

  let logger t = t.logger

  let root_length t = (Hashtbl.find_exn t.table t.root).length

  let best_tip t = find_exn t t.best_tip

  let successor_hashes t hash =
    let node = Hashtbl.find_exn t.table hash in
    node.successor_hashes

  let rec successor_hashes_rec t hash =
    List.bind (successor_hashes t hash) ~f:(fun succ_hash ->
        succ_hash :: successor_hashes_rec t succ_hash )

  let successors t breadcrumb =
    List.map
      (successor_hashes t (Breadcrumb.state_hash breadcrumb))
      ~f:(find_exn t)

  let rec successors_rec t breadcrumb =
    List.bind (successors t breadcrumb) ~f:(fun succ ->
        succ :: successors_rec t succ )

  let path_map t breadcrumb ~f =
    let rec find_path b =
      let elem = f b in
      let parent_hash = Breadcrumb.parent_hash b in
      if State_hash.equal (Breadcrumb.state_hash b) t.root then []
      else if State_hash.equal parent_hash t.root then [elem]
      else elem :: find_path (find_exn t parent_hash)
    in
    List.rev (find_path breadcrumb)

  (* TODO: create a unit test for hash_path *)
  let hash_path t breadcrumb = path_map t breadcrumb ~f:Breadcrumb.state_hash

  let iter t ~f = Hashtbl.iter t.table ~f:(fun n -> f n.breadcrumb)

  let root t = find_exn t t.root

  let shallow_copy_root_snarked_ledger {root_snarked_ledger; _} =
    Ledger.of_database root_snarked_ledger

  let best_tip_path_length_exn {table; root; best_tip; _} =
    let open Option.Let_syntax in
    let result =
      let%bind best_tip_node = Hashtbl.find table best_tip in
      let%map root_node = Hashtbl.find table root in
      best_tip_node.length - root_node.length
    in
    result |> Option.value_exn

  let common_ancestor t (bc1 : Breadcrumb.t) (bc2 : Breadcrumb.t) :
      State_hash.t =
    let rec go ancestors1 ancestors2 b1 b2 =
      let sh1 = Breadcrumb.state_hash b1 in
      let sh2 = Breadcrumb.state_hash b2 in
      Hash_set.add ancestors1 sh1 ;
      Hash_set.add ancestors2 sh2 ;
      if Hash_set.mem ancestors1 sh2 then sh2
      else if Hash_set.mem ancestors2 sh1 then sh1
      else
        let parent_unless_root breadcrumb =
          if State_hash.equal (Breadcrumb.state_hash breadcrumb) t.root then
            breadcrumb
          else find_exn t (Breadcrumb.parent_hash breadcrumb)
        in
        go ancestors1 ancestors2 (parent_unless_root b1)
          (parent_unless_root b2)
    in
    go
      (Hash_set.create (module State_hash) ())
      (Hash_set.create (module State_hash) ())
      bc1 bc2

  (* Visualize the structure of the transition frontier or a particular node
   * within the frontier (for debugging purposes). *)
  module Visualizor = struct
    let fold t ~f = Hashtbl.fold t.table ~f:(fun ~key:_ ~data -> f data)

    include Visualization.Make_ocamlgraph (Node)

    let to_graph t =
      fold t ~init:empty ~f:(fun (node : Node.t) graph ->
          let graph_with_node = add_vertex graph node in
          List.fold node.successor_hashes ~init:graph_with_node
            ~f:(fun acc_graph successor_state_hash ->
              match State_hash.Table.find t.table successor_state_hash with
              | Some child_node ->
                  add_edge acc_graph node child_node
              | None ->
                  Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
                    ~metadata:
                      [ ( "state_hash"
                        , State_hash.to_yojson successor_state_hash ) ]
                    "Could not visualize node $state_hash. Looks like the \
                     node did not get garbage collected properly" ;
                  acc_graph ) )
  end

  let visualize ~filename (t : t) =
    Out_channel.with_file filename ~f:(fun output_channel ->
        let graph = Visualizor.to_graph t in
        Visualizor.output_graph output_channel graph )

  let visualize_to_string t =
    let graph = Visualizor.to_graph t in
    let buf = Buffer.create 0 in
    let formatter = Format.formatter_of_buffer buf in
    Visualizor.fprint_graph formatter graph ;
    Format.pp_print_flush formatter () ;
    Buffer.contents buf
end
