open Core_kernel
open Protocols.Coda_pow
open Protocols.Coda_transition_frontier
open Coda_base
open Signature_lib

module Max_length = struct
  let length = 2160
end

module type Inputs_intf = sig
  module Staged_ledger_aux_hash : Staged_ledger_aux_hash_intf

  module Ledger_proof_statement :
    Ledger_proof_statement_intf with type ledger_hash := Frozen_ledger_hash.t

  module Ledger_proof : sig
    include
      Ledger_proof_intf
      with type statement := Ledger_proof_statement.t
       and type ledger_hash := Frozen_ledger_hash.t
       and type proof := Proof.t
       and type sok_digest := Sok_message.Digest.t

    include Binable.S with type t := t

    include Sexpable.S with type t := t
  end

  module Transaction_snark_work :
    Transaction_snark_work_intf
    with type proof := Ledger_proof.t
     and type statement := Ledger_proof_statement.t
     and type public_key := Public_key.Compressed.t

  module Staged_ledger_diff :
    Staged_ledger_diff_intf
    with type user_command := User_command.t
     and type user_command_with_valid_signature :=
                User_command.With_valid_signature.t
     and type staged_ledger_hash := Staged_ledger_hash.t
     and type public_key := Public_key.Compressed.t
     and type completed_work := Transaction_snark_work.t
     and type completed_work_checked := Transaction_snark_work.Checked.t

  module External_transition :
    External_transition.S
    with module Protocol_state = Consensus.Mechanism.Protocol_state
     and module Staged_ledger_diff := Staged_ledger_diff

  module Staged_ledger :
    Staged_ledger_intf
    with type diff := Staged_ledger_diff.t
     and type valid_diff :=
                Staged_ledger_diff.With_valid_signatures_and_proofs.t
     and type staged_ledger_hash := Staged_ledger_hash.t
     and type staged_ledger_aux_hash := Staged_ledger_aux_hash.t
     and type ledger_hash := Ledger_hash.t
     and type frozen_ledger_hash := Frozen_ledger_hash.t
     and type public_key := Public_key.Compressed.t
     and type ledger := Ledger.t
     and type ledger_proof := Ledger_proof.t
     and type user_command_with_valid_signature :=
                User_command.With_valid_signature.t
     and type statement := Transaction_snark_work.Statement.t
     and type completed_work := Transaction_snark_work.Checked.t
     and type sparse_ledger := Sparse_ledger.t
     and type ledger_proof_statement := Ledger_proof_statement.t
     and type ledger_proof_statement_set := Ledger_proof_statement.Set.t
     and type transaction := Transaction.t
end

module Make (Inputs : Inputs_intf) :
  Transition_frontier_intf
  with type state_hash := State_hash.t
   and type external_transition := Inputs.External_transition.t
   and type ledger_database := Ledger.Db.t
   and type staged_ledger := Inputs.Staged_ledger.t
   and type masked_ledger := Ledger.Mask.Attached.t
   and type transaction_snark_scan_state := Inputs.Staged_ledger.Scan_state.t =
struct
  type ledger_diff = Inputs.Staged_ledger_diff.t

  (* NOTE: is Consensus_mechanism.select preferable over distance? *)

  exception
    Parent_not_found of ([`Parent of State_hash.t] * [`Target of State_hash.t])

  exception Already_exists of State_hash.t

  let max_length = Max_length.length

  module Breadcrumb = struct
    type t =
      { transition_with_hash:
          (Inputs.External_transition.t, State_hash.t) With_hash.t
      ; staged_ledger: Inputs.Staged_ledger.t sexp_opaque }
    [@@deriving sexp, fields]

    let hash {transition_with_hash; _} = With_hash.hash transition_with_hash

    let parent_hash {transition_with_hash; _} =
      Consensus.Mechanism.Protocol_state.previous_state_hash
        (Inputs.External_transition.protocol_state
           (With_hash.data transition_with_hash))
  end

  type node =
    {breadcrumb: Breadcrumb.t; successor_hashes: State_hash.t list; length: int}

  type t =
    { root_snarked_ledger: Ledger.Db.t
    ; mutable root: State_hash.t
    ; mutable best_tip: State_hash.t
    ; logger: Logger.t
    ; table: node State_hash.Table.t }

  (* TODO: load from and write to disk *)
  let create ~logger ~root_transition ~root_snarked_ledger
      ~root_transaction_snark_scan_state ~root_staged_ledger_diff =
    let logger = Logger.child logger __MODULE__ in
    let root_hash = With_hash.hash root_transition in
    let root_protocol_state =
      Inputs.External_transition.protocol_state
        (With_hash.data root_transition)
    in
    let root_blockchain_state =
      Consensus.Mechanism.Protocol_state.blockchain_state root_protocol_state
    in
    assert (
      Ledger_hash.equal
        (Ledger.Db.merkle_root root_snarked_ledger)
        (Frozen_ledger_hash.to_ledger_hash
           (Consensus.Mechanism.Protocol_state.Blockchain_state.ledger_hash
              root_blockchain_state)) ) ;
    let root_masked_ledger = Ledger.of_database root_snarked_ledger in
    let root_snarked_ledger_hash =
      Frozen_ledger_hash.of_ledger_hash
      @@ Ledger.merkle_root (Ledger.of_database root_snarked_ledger)
    in
    assert (
      Ledger_hash.equal
        (Ledger.Mask.Attached.merkle_root root_masked_ledger)
        (Staged_ledger_hash.ledger_hash
           (Consensus.Mechanism.Protocol_state.Blockchain_state
            .staged_ledger_hash root_blockchain_state)) ) ;
    match
      Inputs.Staged_ledger.of_scan_state_and_ledger
        ~scan_state:root_transaction_snark_scan_state
        ~ledger:root_masked_ledger
        ~snarked_ledger_hash:root_snarked_ledger_hash
    with
    | Error e -> failwith (Error.to_string_hum e)
    | Ok pre_root_staged_ledger ->
        let root_staged_ledger =
          match root_staged_ledger_diff with
          | None -> pre_root_staged_ledger
          | Some diff -> (
            match
              Inputs.Staged_ledger.apply pre_root_staged_ledger diff ~logger
            with
            | Error e -> failwith (Error.to_string_hum e)
            | Ok (_, _, `Updated_staged_ledger _root_staged_ledger) ->
                failwith
                  "Use staged_ledger_hash and ledger proof emitted after apply"
            )
        in
        let root_breadcrumb =
          { Breadcrumb.transition_with_hash= root_transition
          ; staged_ledger= root_staged_ledger }
        in
        let root_node =
          {breadcrumb= root_breadcrumb; successor_hashes= []; length= 0}
        in
        let table = State_hash.Table.of_alist_exn [(root_hash, root_node)] in
        { logger
        ; root_snarked_ledger
        ; root= root_hash
        ; best_tip= root_hash
        ; table }

  let all_breadcrumbs t =
    List.map (Hashtbl.data t.table) ~f:(fun {breadcrumb; _} -> breadcrumb)

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

  let attach_node_to t ~parent_node ~node =
    let hash = Breadcrumb.hash node.breadcrumb in
    if
      not
        (State_hash.equal
           (Breadcrumb.hash parent_node.breadcrumb)
           (Breadcrumb.parent_hash node.breadcrumb))
    then
      failwith
        "invalid call to attach_to: hash parent_node <> parent_hash node" ;
    if
      Hashtbl.add t.table ~key:(Breadcrumb.hash node.breadcrumb) ~data:node
      <> `Ok
    then Error.raise (Error.of_exn (Already_exists hash)) ;
    Hashtbl.set t.table
      ~key:(Breadcrumb.hash parent_node.breadcrumb)
      ~data:
        { parent_node with
          successor_hashes= hash :: parent_node.successor_hashes }

  let attach_breadcrumb_exn t breadcrumb =
    let hash = Breadcrumb.hash breadcrumb in
    let parent_hash = Breadcrumb.parent_hash breadcrumb in
    let parent_node =
      Option.value_exn
        (Hashtbl.find t.table parent_hash)
        ~error:
          (Error.of_exn (Parent_not_found (`Parent parent_hash, `Target hash)))
    in
    let node =
      {breadcrumb; successor_hashes= []; length= parent_node.length + 1}
    in
    attach_node_to t ~parent_node ~node

  let _root_successor t parent_node =
    let new_length = parent_node.length + 1 in
    let root_node = Hashtbl.find_exn t.table t.root in
    let root_hash = With_hash.hash root_node.breadcrumb.transition_with_hash in
    let distance_to_root = new_length - root_node.length in
    if distance_to_root > max_length then
      `Changed_root (List.hd_exn (path t parent_node.breadcrumb))
    else `Same_root root_hash

  (* Adding a transition to the transition frontier is broken into the following steps:
   *   1) create a new breadcrumb for a transition
   *   2) attach the breadcrumb to the transition frontier
   *   3) move the root if the path to the new node is longer than the max length
   *     a) calculate the distance from the new node to the parent
   *     b) if the distance is greater than the max length:
   *       I  ) find the immediate successor of the old root in the path to the
   *            longest node and make it the new root
   *       II ) find all successors of the other immediate successors of the old root
   *       III) remove the old root and all of the nodes found in (II) from the table
   *       IV ) merge the old root's merkle mask into the root ledger
   *   4) set the new node as the best tip if the new node has a greater length than
   *      the current best tip
   *)
  let add_transition_exn t transition_with_hash =
    let root_node = Hashtbl.find_exn t.table t.root in
    let best_tip_node = Hashtbl.find_exn t.table t.best_tip in
    let transition = With_hash.data transition_with_hash in
    let hash = With_hash.hash transition_with_hash in
    let parent_hash =
      Consensus.Mechanism.Protocol_state.previous_state_hash
        (Inputs.External_transition.protocol_state transition)
    in
    let parent_node =
      Option.value_exn
        (Hashtbl.find t.table parent_hash)
        ~error:
          (Error.of_exn (Parent_not_found (`Parent parent_hash, `Target hash)))
    in
    (* 1.a ; b *)
    let ( `Hash_after_applying _hash
        , `Ledger_proof _proof
        , `Updated_staged_ledger staged_ledger ) =
      Inputs.Staged_ledger.apply ~logger:t.logger
        (Breadcrumb.staged_ledger parent_node.breadcrumb)
        (Inputs.External_transition.staged_ledger_diff transition)
      |> Or_error.ok_exn
    in
    let breadcrumb = {Breadcrumb.transition_with_hash; staged_ledger} in
    (* 2 *)
    attach_breadcrumb_exn t breadcrumb ;
    let node = Hashtbl.find_exn t.table hash in
    (* 3.a *)
    let distance_to_parent = root_node.length - node.length in
    (* 3.b *)
    if distance_to_parent > max_length then (
      (* 3.b.I *)
      let new_root_hash = List.hd_exn (path t node.breadcrumb) in
      (* 3.b.II *)
      let garbage_immediate_successors =
        List.filter root_node.successor_hashes ~f:(fun succ_hash ->
            not (State_hash.equal succ_hash new_root_hash) )
      in
      (* 3.b.III *)
      let garbage =
        t.root
        :: List.bind garbage_immediate_successors ~f:(successor_hashes_rec t)
      in
      t.root <- new_root_hash ;
      List.iter garbage ~f:(Hashtbl.remove t.table) ;
      (* 3.b.IV *)
      Ledger.Mask.Attached.commit
        (Inputs.Staged_ledger.ledger
           (Breadcrumb.staged_ledger root_node.breadcrumb)) ) ;
    (* 4 *)
    if node.length > best_tip_node.length then t.best_tip <- hash ;
    node.breadcrumb
end

let%test_module "Transition_frontier tests" =
  ( module struct
    (*
  let%test "transitions can be added and interface will work at any point" =

    let module Frontier = Make (struct
      module State_hash = Test_mocks.Hash.Int_unchecked
      module External_transition = Test_mocks.External_transition.T
      module Max_length = struct
        let length = 5
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
      let trans = Quickcheck.random_value ~seed:`Nondeterministic (External_transition.gen base_hash) in
      add_exn t trans
    in

    interface_works ();
    for i = 1 to 200 do
      add_transition ();
      interface_works ()
    done
     *)
  
  end )
