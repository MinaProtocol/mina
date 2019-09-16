open Core_kernel
open Coda_base
open Coda_state
open Module_version

(* TODO: refactor into core_structure + traversals (GADT over fold, derive others from fold) *)

module Make (Inputs : Inputs.S) : sig
  open Inputs

  include Coda_intf.Transition_frontier_creatable_intf
    with type mostly_validated_external_transition :=
                ( [`Time_received] * Truth.true_t
                , [`Proof] * Truth.true_t
                , [`Frontier_dependencies] * Truth.true_t
                , [`Staged_ledger_diff] * Truth.false_t )
                External_transition.Validation.with_transition
     and type external_transition_validated := External_transition.Validated.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type staged_ledger := Staged_ledger.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type verifier := Verifier.t

  val set_hash_unsafe : t -> [`I_promise_this_is_safe of Hash.t] -> unit

  val hash : t -> Hash.t

  val calculate_diffs : t -> Breadcrumb.t -> Diff.Full.E.t list

  val apply_diffs : t -> Diff.Full.E.t list -> [`New_root of Root_identifier.t option]
end = struct
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

  module Root_identifier = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t =
            { state_hash: State_hash.Stable.V1.t
            ; frontier_hash: Hash.Stable.V1.t }
          [@@deriving bin_io, yojson, version]
        end

        include T
        include Registration.Make_latest_version (T)
      end

      module Latest = V1

      module Module_decl = struct
        let name = "transition_frontier_root_identifier"

        type latest = Latest.t
      end

      module Registrar = Registration.Make (Module_decl)
      module Registered_V1 = Registrar.Register (V1)
    end

    include Stable.Latest
  end

  module Root_data = struct
    type t =
      { transition: (External_transition.Validated.Stable.V1.t, State_hash.Stable.V1.t) With_hash.Stable.V1.t
      ; staged_ledger: Staged_ledger.t }

    let minimize {transition; staged_ledger} =
      let open Diff.Minimal_root_data.Stable.Latest in
      { hash= With_hash.hash transition
      ; scan_state= Staged_ledger.scan_state staged_ledger
      ; pending_coinbase= Staged_ledger.pending_coinbase_collection staged_ledger }
  end

  (* Invariant: The path from the root to the tip inclusively, will be max_length *)
  type t =
    { root_ledger: Ledger.Db.t
    ; mutable root: State_hash.t
    ; mutable best_tip: State_hash.t
    ; mutable hash: Hash.t
    ; logger: Logger.t
    ; table: Node.t State_hash.Table.t
    ; consensus_local_state: Consensus.Data.Local_state.t }

  let create ~logger ~root_data ~root_ledger ~base_hash ~consensus_local_state =
    let open Root_data in
    let root_hash = With_hash.hash root_data.transition in
    let root_protocol_state =
      External_transition.Validated.protocol_state
        (With_hash.data root_data.transition)
    in
    let root_blockchain_state =
      Protocol_state.blockchain_state root_protocol_state
    in
    let root_blockchain_state_ledger_hash =
      Blockchain_state.snarked_ledger_hash root_blockchain_state
    in
    assert (
      Frozen_ledger_hash.equal
        (Frozen_ledger_hash.of_ledger_hash (Ledger.Db.merkle_root root_ledger))
        root_blockchain_state_ledger_hash) ;
    let root_breadcrumb = Breadcrumb.create root_data.transition root_data.staged_ledger in
    let root_node =
      {Node.breadcrumb= root_breadcrumb; successor_hashes= []; length= 0}
    in
    let table = State_hash.Table.of_alist_exn [(root_hash, root_node)] in
    { logger
    ; root_ledger
    ; root= root_hash
    ; best_tip= root_hash
    ; hash= base_hash
    ; table
    ; consensus_local_state }

  let consensus_local_state {consensus_local_state; _} = consensus_local_state

  let set_hash_unsafe t (`I_promise_this_is_safe hash) = t.hash <- hash

  let hash t = t.hash

  let all_breadcrumbs t =
    List.map (Hashtbl.data t.table) ~f:(fun {breadcrumb; _} -> breadcrumb)

  let find t hash =
    let open Option.Let_syntax in
    let%map node = Hashtbl.find t.table hash in
    node.breadcrumb

  let find_exn t hash =
    let node = Hashtbl.find_exn t.table hash in
    node.breadcrumb

  let get_root t = find t t.root

  let get_root_exn t = find_exn t t.root

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

  let shallow_copy_root_snarked_ledger {root_ledger; _} =
    Ledger.of_database root_ledger

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

  (* given an heir, calculate the diff that will transition the root to that heir *)
  let calculate_root_transition_diff t heir =
    let open Diff.Minimal_root_data.Stable.V1 in
    let root = root t in
    let heir_hash = Breadcrumb.state_hash heir in
    let heir_staged_ledger = Breadcrumb.staged_ledger heir in
    let heir_siblings =
      List.filter (successors t root) ~f:(fun breadcrumb ->
        not (State_hash.equal heir_hash (Breadcrumb.state_hash breadcrumb)))
    in
    let garbage_breadcrumbs = List.bind heir_siblings ~f:(fun sibling -> sibling :: successors_rec t sibling) in
    let garbage_hashes = List.map garbage_breadcrumbs ~f:Breadcrumb.state_hash in
    let new_root_data =
      { hash= heir_hash
      ; scan_state= Staged_ledger.scan_state heir_staged_ledger
      ; pending_coinbase= Staged_ledger.pending_coinbase_collection heir_staged_ledger }
    in
    Diff.Full.E.E (Root_transitioned {new_root= new_root_data; garbage= garbage_hashes})

  (* calculates the diffs which need to be applied in order to add a breadcrumb to the frontier *)
  let calculate_diffs t breadcrumb = 
    let open Diff in
    O1trace.measure "calculate_diffs" (fun () ->
      let breadcrumb_hash = Breadcrumb.state_hash breadcrumb in
      let parent_node = Hashtbl.find_exn t.table (Breadcrumb.parent_hash breadcrumb) in
      let root_node = Hashtbl.find_exn t.table t.root in
      let current_best_tip = best_tip t in
      let diffs = [Full.E.E (New_node (Full breadcrumb))] in
      (* check if new breadcrumb extends frontier to longer than k *)
      let diffs =
        if (parent_node.length + 1) - root_node.length > max_length then
          let heir = find_exn t (List.hd_exn (hash_path t breadcrumb)) in
          calculate_root_transition_diff t heir :: diffs
        else
          diffs
      in
      (* check if new breadcrumb will be best tip *)
      let diffs =
        if
          Consensus.Hooks.select
            ~existing:(Breadcrumb.consensus_state current_best_tip)
            ~candidate:(Breadcrumb.consensus_state breadcrumb)
            ~logger:
              (Logger.extend t.logger
                 [ ( "selection_context"
                   , `String "comparing new breadcrumb to best tip" ) ])
          = `Take
        then
          Full.E.E (Best_tip_changed breadcrumb_hash) :: diffs
        else
          diffs
      in
      (* reverse diffs so that they are applied in the correct order *)
      List.rev diffs)

  let apply_diff (type mutant) t (diff : (Diff.full, mutant) Diff.t) : mutant * State_hash.t option =
    match diff with
    | New_node (Full breadcrumb) ->
        let breadcrumb_hash = Breadcrumb.state_hash breadcrumb in
        let parent_hash = Breadcrumb.parent_hash breadcrumb in
        let parent_node = Hashtbl.find_exn t.table parent_hash in
        Hashtbl.add_exn t.table
          ~key:breadcrumb_hash
          ~data:{breadcrumb; successor_hashes=[]; length= parent_node.length + 1};
        Hashtbl.set t.table
          ~key:parent_hash
          ~data:{parent_node with successor_hashes= breadcrumb_hash :: parent_node.successor_hashes};
        (), None
    | Best_tip_changed new_best_tip ->
        let old_best_tip = t.best_tip in
        t.best_tip <- new_best_tip;
        old_best_tip, None
    | Root_transitioned {new_root= {hash= new_root_hash; _}; garbage} ->
        (* this seems incomplete and is most certainly missing some steps (e.g. update root ledger if proof emitted) *)
        List.iter garbage ~f:(Hashtbl.remove t.table);
        let mask_of_node (node : Node.t) = Staged_ledger.ledger (Breadcrumb.staged_ledger node.breadcrumb) in
        let old_root_node = Hashtbl.find_exn t.table t.root in
        let new_root_node = Hashtbl.find_exn t.table new_root_hash in
        let new_root_mask = mask_of_node new_root_node in
        let new_root_mask_hash = Ledger.merkle_root new_root_mask in
        let new_root_successor_masks = 
          List.map new_root_node.successor_hashes ~f:(Fn.compose mask_of_node (Hashtbl.find_exn t.table))
        in
        Ledger.commit new_root_mask;
        [%test_result: Ledger_hash.t]
          ~message:
            "Merkle root of soon-to-be-root before commit, is same as root \
             ledger's merkle root afterwards"
          ~expect:new_root_mask_hash (Ledger.merkle_root new_root_mask) ;
        let new_root_breadcrumb =
          Breadcrumb.create
            (Breadcrumb.transition_with_hash new_root_node.breadcrumb)
            (Staged_ledger.replace_ledger_exn (Breadcrumb.staged_ledger new_root_node.breadcrumb) new_root_mask)
        in
        let new_root_node = {new_root_node with breadcrumb= new_root_breadcrumb} in
        Ledger.remove_and_reparent_exn new_root_mask new_root_mask ~children:new_root_successor_masks;
        List.iter (t.root :: garbage) ~f:(Hashtbl.remove t.table);
        Hashtbl.set t.table ~key:new_root_hash ~data:new_root_node;
        t.root <- new_root_hash;
        Breadcrumb.state_hash old_root_node.breadcrumb, Some new_root_hash
    | New_node (Lite _) -> failwith "impossible"

  let apply_diffs t diffs =
    let open Root_identifier.Stable.Latest in
    let new_root =
      List.fold diffs ~init:None ~f:(fun prev_root (Diff.Full.E.E diff) ->
        let mutant, new_root = apply_diff t diff in
        t.hash <- Hash.merge_diff t.hash (Diff.to_lite diff) mutant;
        match new_root with
        | None -> prev_root
        | Some state_hash -> Some {state_hash; frontier_hash= t.hash})
    in
    `New_root new_root

  (* TODO: separate visualizer? *)
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
