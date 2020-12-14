open Core_kernel
open Mina_base
open Frontier_base

module Catchup_job_id = Unique_id.Int ()

module Node = struct
  module State = struct
    type t = Have_breadcrumb | Part_of_catchups of Catchup_job_id.Hash_set.t
  end

  type t =
    { parent: State_hash.t
    ; state: State.t
          (* If a node has a breadcrumb, then all of its ancestors have
   breadcrumbs as well. *)
    }
end

type t =
  { nodes: Node.t State_hash.Table.t
  ; tips: State_hash.Hash_set.t
  ; children: State_hash.Set.t State_hash.Table.t
  ; mutable root: State_hash.t
  ; logger: Logger.t }

let max_catchup_chain_length t =
  let rec missing_length acc (node : Node.t) =
    match node.state with
    | Have_breadcrumb ->
        acc
    | Part_of_catchups _ -> (
      match Hashtbl.find t.nodes node.parent with
      | None ->
          (* This node is a root. *)
          acc
      | Some parent ->
          missing_length (acc + 1) parent )
  in
  Hash_set.fold t.tips ~init:0 ~f:(fun acc tip ->
      Int.max acc (missing_length 0 (Hashtbl.find_exn t.nodes tip)) )

let create ~root =
  let root_hash = Breadcrumb.state_hash root in
  let parent = Breadcrumb.parent_hash root in
  let nodes =
    State_hash.Table.of_alist_exn
      [(root_hash, {Node.parent; state= Have_breadcrumb})]
  in
  { root= root_hash
  ; tips= State_hash.Hash_set.create ()
  ; children=
      State_hash.Table.of_alist_exn
        [(parent, State_hash.Set.singleton root_hash)]
  ; nodes
  ; logger= Logger.create () }

let check_for_parent t h ~parent:p ~check_has_breadcrumb =
  let log s =
    [%log' warn t.logger]
      ~metadata:
        [("parent", State_hash.to_yojson p); ("hash", State_hash.to_yojson h)]
      "hash tree invariant broken: %s" s
  in
  match Hashtbl.find t.nodes p with
  | None ->
      log "$parent not found in hash-tree for $hash"
  | Some x ->
      if check_has_breadcrumb && x.state <> Have_breadcrumb then
        log "expected $parent to have breadcrumb (child is $hash)"
      else ()

let add_child t h ~parent =
  Hashtbl.update t.children parent ~f:(function
    | None ->
        State_hash.Set.singleton h
    | Some s ->
        Set.add s h )

let add t h ~parent ~job =
  if Hashtbl.mem t.nodes h then
    match (Hashtbl.find_exn t.nodes h).state with
    | Have_breadcrumb ->
        ()
    | Part_of_catchups s ->
        Hash_set.add s job
  else (
    check_for_parent t h ~parent ~check_has_breadcrumb:false ;
    if not (Hashtbl.mem t.children h) then Hash_set.add t.tips h ;
    add_child t h ~parent ;
    Hash_set.remove t.tips parent ;
    Hashtbl.set t.nodes ~key:h
      ~data:
        {parent; state= Part_of_catchups (Catchup_job_id.Hash_set.create ())} )

let breadcrumb_added (t : t) b =
  let h = Breadcrumb.state_hash b in
  let parent = Breadcrumb.parent_hash b in
  check_for_parent t h ~parent ~check_has_breadcrumb:true ;
  Hashtbl.update t.nodes h ~f:(function
    | None ->
        (* New child *)
        add_child t h ~parent ;
        {parent; state= Have_breadcrumb}
    | Some x ->
        {x with state= Have_breadcrumb} ) ;
  Hash_set.remove t.tips h

let remove_node t h =
  Hash_set.remove t.tips h ;
  match Hashtbl.find_and_remove t.nodes h with
  | None ->
      ()
  | Some {parent; _} ->
      Hashtbl.change t.children parent ~f:(function
        | None ->
            None
        | Some s ->
            let s' = Set.remove s h in
            if Set.is_empty s' then None else Some s' )

(* Remove everything not reachable from the root *)
let prune t =
  let keep = State_hash.Hash_set.create () in
  let rec go stack =
    match stack with
    | [] ->
        ()
    | next :: stack ->
        Hash_set.add keep next ;
        let stack =
          match Hashtbl.find t.children next with
          | None ->
              stack
          | Some cs ->
              List.rev_append (Set.to_list cs) stack
        in
        go stack
  in
  go [t.root] ;
  List.iter (Hashtbl.keys t.nodes) ~f:(fun h ->
      if not (Hash_set.mem keep h) then remove_node t h )

let catchup_failed t job =
  let to_remove =
    Hashtbl.fold t.nodes ~init:[] ~f:(fun ~key ~data acc ->
        match data.state with
        | Have_breadcrumb ->
            acc
        | Part_of_catchups s ->
            Hash_set.remove s job ;
            if Hash_set.is_empty s then key :: acc else acc )
  in
  List.iter to_remove ~f:(remove_node t)

let apply_diffs t (ds : Diff.Full.E.t list) =
  List.iter ds ~f:(function
    | E (New_node (Full b)) ->
        breadcrumb_added t b
    | E (Root_transitioned {new_root; garbage= Full hs}) ->
        List.iter (Diff.Node_list.to_lite hs) ~f:(remove_node t) ;
        let h = Root_data.Limited.hash new_root in
        Hashtbl.change t.nodes h ~f:(function
          | None ->
              [%log' warn t.logger]
                ~metadata:[("hash", State_hash.to_yojson h)]
                "hash tree invariant broken: new root $hash not present. \
                 Diffs may have been applied out of order" ;
              None
          | Some x ->
              t.root <- h ;
              Some {x with state= Have_breadcrumb} ) ;
        prune t
    | E (Best_tip_changed _) ->
        () )
