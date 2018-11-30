open Core_kernel
open Protocols.Coda_pow

module type Inputs_intf = sig
  module Time : Time_intf

  module Proof : Proof_intf

  module State_hash : Hash_intf

  module Ledger_hash : Ledger_hash_intf

  module Frozen_ledger_hash :
    Frozen_ledger_hash_intf with type ledger_hash := Ledger_hash.t

  module Ledger_builder_aux_hash : Ledger_builder_aux_hash_intf

  module Ledger_builder_hash :
    Ledger_builder_hash_intf
    with type ledger_hash := Ledger_hash.t
     and type ledger_builder_aux_hash := Ledger_builder_aux_hash.t

  module Ledger_builder_diff : Ledger_builder_diff_intf

  module Blockchain_state :
    Blockchain_state_intf
    with type ledger_builder_hash := Ledger_builder_hash.t
     and type frozen_ledger_hash := Frozen_ledger_hash.t
     and type time := Time.t

  module Consensus_state : Consensus_state_intf

  module Protocol_state :
    Protocol_state_intf
    with type state_hash := State_hash.t
     and type blockchain_state := Blockchain_state.value
     and type consensus_state := Consensus_state.value

  module External_transition :
    sig
      include External_transition_intf

      type transition_frontier_root_hash

      val create :
           protocol_state:protocol_state
        -> protocol_state_proof:protocol_state_proof
        -> ledger_builder_diff:ledger_builder_diff
        -> transition_frontier_root_hash:transition_frontier_root_hash
        -> t

      val transition_frontier_root_hash : t -> transition_frontier_root_hash
    end
    with type protocol_state := Protocol_state.value
     and type protocol_state_proof := Proof.t
     and type ledger_builder_diff := Ledger_builder_diff.t
     and type transition_frontier_root_hash := State_hash.t

  module Key : Merkle_ledger.Intf.Key

  module Account : Merkle_ledger.Intf.Account with type key := Key.t

  module Location : Merkle_ledger.Location_intf.S

  module Ledger_diff : sig
    type t
  end

  module Any_base :
    Merkle_mask.Base_merkle_tree_intf.S
    with module Addr = Location.Addr
     and module Location = Location
     and type account := Account.t
     and type root_hash := Ledger_hash.t
     and type hash := Ledger_hash.t
     and type key := Key.t

  module Ledger_mask : sig
    include
      Merkle_mask.Masking_merkle_tree_intf.S
      with module Addr = Location.Addr
       and module Location = Location
       and module Attached.Addr = Location.Addr
       and type account := Account.t
       and type location := Location.t
       and type key := Key.t
       and type hash := Ledger_hash.t
       and type parent := Any_base.t

    val merkle_root : t -> Ledger_hash.t

    val apply : t -> Ledger_diff.t -> unit

    val commit : t -> unit
  end

  module Ledger_database : sig
    include
      Merkle_ledger.Database_intf.S
      with module Location = Location
       and module Addr = Location.Addr
       and type account := Account.t
       and type root_hash := Ledger_hash.t
       and type hash := Ledger_hash.t
       and type key := Key.t

    val derive : t -> Ledger_mask.t
  end

  module Transaction_snark_scan_state : sig
    type t

    module Diff : sig
      type t

      (* hack until Parallel_scan_state().Diff.t fully diverges from Ledger_builder_diff.t and is included in External_transition *)
      val of_ledger_builder_diff : Ledger_builder_diff.t -> t
    end
  end

  module Staged_ledger : sig
    type t

    val create :
         transaction_snark_scan_state:Transaction_snark_scan_state.t
      -> ledger_mask:Ledger_mask.t
      -> t

    val transaction_snark_scan_state : t -> Transaction_snark_scan_state.t

    val ledger_mask : t -> Ledger_mask.t

    val apply : t -> Transaction_snark_scan_state.Diff.t -> t Or_error.t
  end

  module Max_length : sig
    val t : int
  end
end

(* NOTE: is Consensus_mechanism.select preferable over distance? *)
module Make (Inputs : Inputs_intf) :
  Transition_frontier_intf
  with type state_hash := Inputs.State_hash.t
   and type external_transition := Inputs.External_transition.t
   and type ledger_database := Inputs.Ledger_database.t
   and type transaction_snark_scan_state :=
              Inputs.Transaction_snark_scan_state.t
   and type ledger_diff := Inputs.Ledger_diff.t
   and type staged_ledger := Inputs.Staged_ledger.t
   and type protocol_state := Inputs.Protocol_state.value
   and type protocol_state_proof := Inputs.Proof.t
   and type ledger_builder_diff := Inputs.Ledger_builder_diff.t = struct
  open Inputs

  exception
    Parent_not_found of ([`Parent of State_hash.t] * [`Target of State_hash.t])

  exception Already_exists of State_hash.t

  exception Bad_root_hash_in_transition of State_hash.t

  let max_length = Max_length.t

  module Breadcrumb = struct
    type t =
      { transition_with_hash: (External_transition.t, State_hash.t) With_hash.t
      ; staged_ledger: Staged_ledger.t }
    [@@deriving fields]

    let hash {transition_with_hash; _} = With_hash.hash transition_with_hash

    let parent_hash {transition_with_hash; _} =
      Protocol_state.previous_state_hash
        (External_transition.protocol_state
           (With_hash.data transition_with_hash))
  end

  type node =
    {breadcrumb: Breadcrumb.t; successor_hashes: State_hash.t list; length: int}

  type t =
    { root_snarked_ledger: Ledger_database.t
    ; mutable root: State_hash.t
    ; mutable best_tip: State_hash.t
    ; table: node State_hash.Table.t }

  (* TODO: load from and write to disk *)
  let create ~root_transition ~root_snarked_ledger
      ~root_transaction_snark_scan_state ~root_staged_ledger_diff =
    let root_hash = With_hash.hash root_transition in
    let root_protocol_state =
      External_transition.protocol_state (With_hash.data root_transition)
    in
    let root_blockchain_state =
      Protocol_state.blockchain_state root_protocol_state
    in
    assert (
      Ledger_hash.equal
        (Ledger_database.merkle_root root_snarked_ledger)
        (Frozen_ledger_hash.to_ledger_hash
           (Blockchain_state.ledger_hash root_blockchain_state)) ) ;
    let root_staged_ledger_mask = Ledger_database.derive root_snarked_ledger in
    Ledger_mask.apply root_staged_ledger_mask root_staged_ledger_diff ;
    assert (
      Ledger_hash.equal
        (Ledger_mask.merkle_root root_staged_ledger_mask)
        (Ledger_builder_hash.ledger_hash
           (Blockchain_state.ledger_builder_hash root_blockchain_state)) ) ;
    let root_staged_ledger =
      Staged_ledger.create
        ~transaction_snark_scan_state:root_transaction_snark_scan_state
        ~ledger_mask:root_staged_ledger_mask
    in
    let root_breadcrumb =
      { Breadcrumb.transition_with_hash= root_transition
      ; staged_ledger= root_staged_ledger }
    in
    let root_node =
      {breadcrumb= root_breadcrumb; successor_hashes= []; length= 0}
    in
    let table = State_hash.Table.of_alist_exn [(root_hash, root_node)] in
    {root_snarked_ledger; root= root_hash; best_tip= root_hash; table}

  let find t hash =
    let open Option.Let_syntax in
    let%map node = Hashtbl.find t.table hash in
    node.breadcrumb

  let find_exn t hash =
    let node = Hashtbl.find_exn t.table hash in
    node.breadcrumb

  let path t breadcrumb =
    let rec find_path b =
      let hash = Breadcrumb.hash b in
      let parent_hash = Breadcrumb.parent_hash b in
      if State_hash.equal parent_hash t.root then [hash]
      else hash :: find_path (find_exn t parent_hash)
    in
    List.rev (find_path breadcrumb)

  let iter t ~f = Hashtbl.iter t.table ~f:(fun n -> f n.breadcrumb)

  let root t = find_exn t t.root

  let best_tip t = find_exn t t.best_tip

  let successor_hashes t hash =
    let node = Hashtbl.find_exn t.table hash in
    node.successor_hashes

  let rec successor_hashes_rec t hash =
    List.bind (successor_hashes t hash) ~f:(fun succ_hash ->
        succ_hash :: successor_hashes_rec t succ_hash )

  let successors t breadcrumb =
    List.map (successor_hashes t (Breadcrumb.hash breadcrumb)) ~f:(find_exn t)

  let rec successors_rec t breadcrumb =
    List.bind (successors t breadcrumb) ~f:(fun succ ->
        succ :: successors_rec t succ )

  let root_successor t parent_node =
    let new_length = parent_node.length + 1 in
    let root_node = Hashtbl.find_exn t.table t.root in
    let root_hash = With_hash.hash root_node.breadcrumb.transition_with_hash in
    let distance_to_root = new_length - root_node.length in
    if distance_to_root > max_length then
      `Changed_root (List.hd_exn (path t parent_node.breadcrumb))
    else `Same_root root_hash

  (* Adding a transition to the transition frontier is broken into the following steps:
   *   1) create a new node for a transition
   *     a) derive a new mask from the parent mask
   *     b) apply the ledger builder diff to the new mask
   *     c) form the breadcrumb and node records
   *   2) add the node to the table
   *   3) add the successor_hashes entry to the parent node
   *   4) move the root if the path to the new node is longer than the max length
   *     a) find the immediate successor of the old root in the path to the
   *          longest node and make it the new root
   *     b) find all successors of the other immediate successors of the old root
   *     c) remove the old root and all of the nodes found in (b) from the table
   *     d) merge the old root's merkle mask into the root ledger
   *   5) set the new node as the best tip if the new node has a greater length than
   *      the current best tip
   *)
  let add_exn t transition_with_hash =
    let root_node = Hashtbl.find_exn t.table t.root in
    let best_tip_node = Hashtbl.find_exn t.table t.best_tip in
    let transition = With_hash.data transition_with_hash in
    let hash = With_hash.hash transition_with_hash in
    let parent_hash =
      Protocol_state.previous_state_hash
        (External_transition.protocol_state transition)
    in
    let parent_node =
      Option.value_exn
        (Hashtbl.find t.table parent_hash)
        ~error:
          (Error.of_exn (Parent_not_found (`Parent parent_hash, `Target hash)))
    in
    let parent_root_suc = root_successor t parent_node in
    (* 1.a ; b *)
    let staged_ledger =
      Staged_ledger.apply
        (Breadcrumb.staged_ledger parent_node.breadcrumb)
        (Transaction_snark_scan_state.Diff.of_ledger_builder_diff
           (External_transition.ledger_builder_diff transition))
      |> Or_error.ok_exn
    in
    (* 1.c *)
    let node =
      { breadcrumb= {Breadcrumb.transition_with_hash; staged_ledger}
      ; successor_hashes= []
      ; length= parent_node.length + 1 }
    in
    (* 2 *)
    if Hashtbl.add t.table ~key:hash ~data:node <> `Ok then
      Error.raise (Error.of_exn (Already_exists hash)) ;
    (let h =
       match parent_root_suc with `Changed_root h | `Same_root h -> h
     in
     if
       not
         (State_hash.equal h
            (External_transition.transition_frontier_root_hash transition))
     then raise (Bad_root_hash_in_transition h)) ;
    (* 3 *)
    Hashtbl.set t.table ~key:parent_hash
      ~data:
        { parent_node with
          successor_hashes= hash :: parent_node.successor_hashes } ;
    (* 4. *)
    ( match parent_root_suc with
    | `Changed_root new_root_hash ->
        (* 4.b *)
        let garbage_immediate_successors =
          List.filter root_node.successor_hashes ~f:(fun succ_hash ->
              not (State_hash.equal succ_hash new_root_hash) )
        in
        (* 4.c *)
        let garbage =
          t.root
          :: List.bind garbage_immediate_successors ~f:(successor_hashes_rec t)
        in
        t.root <- new_root_hash ;
        List.iter garbage ~f:(Hashtbl.remove t.table) ;
        (* 4.d*)
        Ledger_mask.commit
          (Staged_ledger.ledger_mask
             (Breadcrumb.staged_ledger root_node.breadcrumb))
    | `Same_root _same_hash -> () ) ;
    (* 5 *)
    if node.length > best_tip_node.length then t.best_tip <- hash ;
    node.breadcrumb

  let root_successor t hash =
    match root_successor t (Hashtbl.find_exn t.table hash) with
    | `Same_root h | `Changed_root h -> h
end

let%test_module "Transition_frontier tests" =
  ( module struct
    (*
  let%test "transitions can be added and interface will work at any point" =
                                                p
    let module Frontier = Make (struct
      module State_hash = Test_mocks.Hash.Int_unchecked
      module External_transition = Test_mocks.External_transition.T
      module Max_length = struct
        let t = 5
      end
    end) in
    let open Frontier in
    let t = create ~log:(Logger.create ()) in

    (* test that functions that shouldn't throw exceptions don't *)
    let interface_works () =
      let r = root t in
      ignore (best_tip t);
      ignore (successor_hashes_rec r);
      ignore (successors_rec r);
      iter t ~f:(fun b ->
          let h = Breadcrumb.hash b in
          find_exn t h;
          ignore (successor_hashes t h)
          ignore (successors t b))
    in

    (* add a single random transition based off a random node *)
    let add_transition () =
      let base_hash = List.head_exn (List.shuffle (hashes t)) in
      let trans = Quickcheck.random_value (External_transition.gen base_hash) in
      add_exn t trans
    in

    interface_works ();
    for i = 1 to 200 do
      add_transition ();
      interface_works ()
    done
  *)
  
  end )
