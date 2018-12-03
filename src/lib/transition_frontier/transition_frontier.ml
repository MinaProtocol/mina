open Core_kernel
open Protocols.Coda_pow

module Time : Time_intf = Coda_base.Block_time

module Proof : Proof_intf = struct
  (* TODO: missing bits *)
  include Coda_base.Proof

  type input

  let verify _ = failwith "verify: missing"
end

module State_hash : Hash_intf = Coda_base.State_hash

module Ledger_hash : Ledger_hash_intf with type t := Coda_base.Ledger_hash.t =
  Coda_base.Ledger_hash

module Frozen_ledger_hash :
  Frozen_ledger_hash_intf
  with type ledger_hash := Coda_base.Ledger_hash.t
   and type t := Coda_base.Frozen_ledger_hash.t =
  Coda_base.Frozen_ledger_hash

module Ledger_builder_aux_hash :
  Ledger_builder_aux_hash_intf
  with type t = Coda_base.Ledger_builder_hash.Aux_hash.t = struct
  include Coda_base.Ledger_builder_hash.Aux_hash.Stable.V1

  let of_bytes = Coda_base.Ledger_builder_hash.Aux_hash.of_bytes
end

module Ledger_builder_hash :
  Ledger_builder_hash_intf
  with type t := Coda_base.Ledger_builder_hash.t
   and type ledger_hash := Coda_base.Ledger_hash.t
   and type ledger_builder_aux_hash := Coda_base.Ledger_builder_hash.Aux_hash.t =
struct
  include Coda_base.Ledger_builder_hash.Stable.V1

  let ledger_hash = Coda_base.Ledger_builder_hash.ledger_hash

  let aux_hash = Coda_base.Ledger_builder_hash.aux_hash

  let of_aux_and_ledger_hash =
    Coda_base.Ledger_builder_hash.of_aux_and_ledger_hash
end

module Ledger_proof = struct
  type t [@@deriving sexp, bin_io]
end

module Ledger_proof_statement = Transaction_snark.Statement
module Completed_work =
  Ledger_builder.Make_completed_work
    (Signature_lib.Public_key.Compressed)
    (Ledger_proof)
    (Ledger_proof_statement)

module User_command = struct
  (* TODO: write missing bits *)
  include Coda_base.User_command

  let check _ = failwith "check: missing"

  let fee _ = failwith "fee: missing"

  let sender _ = failwith "fee: missing"
end

module Inputs_ledger_builder_diff = struct
  module Ledger_hash = Coda_base.Ledger_hash
  module Ledger_proof = Ledger_proof
  module Ledger_builder_aux_hash = Ledger_builder_aux_hash
  module Compressed_public_key = Signature_lib.Public_key.Compressed
  module User_command = User_command
  module Completed_work =
    Ledger_builder.Make_completed_work
      (Signature_lib.Public_key.Compressed)
      (Ledger_proof)
      (Ledger_proof_statement)
  module Ledger_builder_hash = Coda_base.Ledger_builder_hash
end

module Ledger_builder_diff :
  Ledger_builder_diff_intf
  with type completed_work_checked := Completed_work.Checked.t
   and type completed_work := Completed_work.t
   and type ledger_builder_hash := Coda_base.Ledger_builder_hash.t
   and type public_key := Signature_lib.Public_key.Compressed.t
   and type user_command := Coda_base.User_command.t
   and type user_command_with_valid_signature :=
              Coda_base.User_command.With_valid_signature.t =
  Ledger_builder.Make_diff (Inputs_ledger_builder_diff)

module Blockchain_state :
  Blockchain_state_intf
  with type ledger_builder_hash := Coda_base.Ledger_builder_hash.t
   and type frozen_ledger_hash := Coda_base.Frozen_ledger_hash.t
   and type time := Coda_base.Block_time.t =
  Consensus.Mechanism.Protocol_state.Blockchain_state

module Inputs_protocol_state : Consensus.Proof_of_signature.Inputs_intf =
struct
  module Time = Time
  module Genesis_ledger = Genesis_ledger

  (* TODO : what's a good interval *)
  let proposal_interval = Time.Span.of_ms 100L
end

module Protocol_state :
  Protocol_state_intf
  with type state_hash := Coda_base.State_hash.t
   and type blockchain_state :=
              Consensus.Mechanism.Protocol_state.Blockchain_state.value
   and type consensus_state :=
              Consensus.Mechanism.Protocol_state.Consensus_state.value =
  Consensus.Mechanism.Protocol_state

module External_transition :
  External_transition_intf
  with type protocol_state := Consensus.Mechanism.Protocol_state.value
   and type protocol_state_proof := Coda_base.Proof.t
   and type ledger_builder_diff := Ledger_builder_diff.t =
  Coda_base.External_transition.Make
    (Ledger_builder_diff)
    (Consensus.Mechanism.Protocol_state)

module Key : Merkle_ledger.Intf.Key with type t = Coda_base.Account.key =
struct
  module T = struct
    type t = Coda_base.Account.key [@@deriving sexp, bin_io, compare, hash, eq]
  end

  let empty = Coda_base.Account.empty.public_key

  include T
  include Hashable.Make_binable (T)
end

module Depth = struct
  let depth = Snark_params.ledger_depth
end

module Location : Merkle_ledger.Location_intf.S =
  Merkle_ledger.Location.Make (Depth)

module Ledger_diff : sig
  type t
end = struct
  type t = int

  (* TODO : use valid type *)
end

module Hash = struct
  type t = Coda_base.Ledger_hash.t [@@deriving bin_io, sexp]

  let merge = Coda_base.Ledger_hash.merge

  let hash_account =
    Fn.compose Coda_base.Ledger_hash.of_digest Coda_base.Account.digest

  let empty_account = hash_account Coda_base.Account.empty
end

module Any_ledger :
  Merkle_ledger.Any_ledger.S
  with module Location = Location
  with type account := Coda_base.Account.t
   and type key := Coda_base.Account.key
   and type hash := Hash.t =
  Merkle_ledger.Any_ledger.Make_base (Key) (Coda_base.Account) (Hash)
    (Location)
    (Depth)

(* N.B. Entering a Base_ledger_intf.S module signature here prevents "derive" below from typing *)
module Any_base = Any_ledger.M

(* a mask module that can accept any base ledger *)
module Ledger_mask : sig
  include
    Merkle_mask.Masking_merkle_tree_intf.S
    with module Addr = Location.Addr
     and module Location = Location
     and module Attached.Addr = Location.Addr
     and type account := Coda_base.Account.t
     and type location := Location.t
     and type key := Key.t
     and type hash := Coda_base.Ledger_hash.t
     and type parent := Any_base.t
  (*  to be added to Attached part of Masking_merkle_tree_intf.S  ?
      val apply : t -> Ledger_diff.t -> unit 
 *)
end =
  Merkle_mask.Masking_merkle_tree.Make (Key) (Coda_base.Account) (Hash)
    (Location)
    (Any_base)

module Maskable :
  Merkle_mask.Maskable_merkle_tree_intf.S
  with module Addr = Location.Addr
   and module Location = Location
  with type account := Coda_base.Account.t
   and type key := Key.t
   and type root_hash := Hash.t
   and type hash := Hash.t
   and type unattached_mask := Ledger_mask.t
   and type attached_mask := Ledger_mask.Attached.t
   and type t := Any_base.t =
  Merkle_mask.Maskable_merkle_tree.Make (Key) (Coda_base.Account) (Hash)
    (Location)
    (Any_base)
    (Ledger_mask)

(* TODO : should this module still exist? *)
module Storage_locations : Merkle_ledger.Intf.Storage_locations = struct
  let stack_db_file = "coda_stack_db"

  let key_value_db_dir = "coda_key_value_db"
end

module Ledger_database : sig
  include
    Merkle_ledger.Database_intf.S
    with module Location = Location
     and module Addr = Location.Addr
     and type account := Coda_base.Account.t
     and type root_hash := Coda_base.Ledger_hash.t
     and type hash := Coda_base.Ledger_hash.t
     and type key := Key.t

  val derive : t -> Ledger_mask.Attached.t
end = struct
  module Db =
    Merkle_ledger.Database.Make (Key) (Coda_base.Account) (Hash) (Depth)
      (Location)
      (Rocksdb_database)
      (Storage_locations)
  include Db

  let derive t =
    let mask = Ledger_mask.create () in
    let casted = Any_ledger.cast (module Db) t in
    Maskable.register_mask casted mask
end

module Max_length = struct
  let length = 5

  (* TODO  : what should this be? *)
end

module Transaction_snark_scan_state : sig
  type t

  module Diff : sig
    type t

    (* hack until Parallel_scan_state().Diff.t fully diverges from Ledger_builder_diff.t and is included in External_transition *)
    val of_ledger_builder_diff : Ledger_builder_diff.t -> t
  end
end = struct
  type t = int

  (* TODO : what should this be? *)
  module Diff = struct
    type t = int

    (* TODO *)
    let of_ledger_builder_diff _ =
      failwith "of_ledger_builder_diff: not implemented"
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
end = struct
  (* TODO *)

  type t = int

  let create ~transaction_snark_scan_state:_ ~ledger_mask:_ =
    failwith "create: not implemented"

  let transaction_snark_scan_state _ =
    failwith "transaction_snark_scan_state: not implemented"

  let ledger_mask _t = failwith "ledger_mask: not implemented"

  let apply _t _ = failwith "apply: not implemented"
end

(* NOTE: is Consensus_mechanism.select preferable over distance? *)

exception
  Parent_not_found of
    ([`Parent of Coda_base.State_hash.t] * [`Target of Coda_base.State_hash.t])

exception Already_exists of Coda_base.State_hash.t

let max_length = Max_length.length

module Breadcrumb = struct
  type t =
    { transition_with_hash:
        (External_transition.t, Coda_base.State_hash.t) With_hash.t
    ; staged_ledger: Staged_ledger.t }
  [@@deriving fields]

  let hash {transition_with_hash; _} = With_hash.hash transition_with_hash

  let parent_hash {transition_with_hash; _} =
    Consensus.Mechanism.Protocol_state.previous_state_hash
      (External_transition.protocol_state (With_hash.data transition_with_hash))
end

type node =
  { breadcrumb: Breadcrumb.t
  ; successor_hashes: Coda_base.State_hash.t list
  ; length: int }

type t =
  { root_snarked_ledger: Ledger_database.t
  ; mutable root: Coda_base.State_hash.t
  ; mutable best_tip: Coda_base.State_hash.t
  ; table: node Coda_base.State_hash.Table.t }

(* TODO: load from and write to disk *)
let create ~root_transition ~root_snarked_ledger
    ~root_transaction_snark_scan_state ~root_staged_ledger_diff =
  let root_hash = With_hash.hash root_transition in
  let root_protocol_state =
    External_transition.protocol_state (With_hash.data root_transition)
  in
  let root_blockchain_state =
    Consensus.Mechanism.Protocol_state.blockchain_state root_protocol_state
  in
  assert (
    Ledger_hash.equal
      (Ledger_database.merkle_root root_snarked_ledger)
      (Frozen_ledger_hash.to_ledger_hash
         (Consensus.Mechanism.Protocol_state.Blockchain_state.ledger_hash
            root_blockchain_state)) ) ;
  let root_staged_ledger_mask = Ledger_database.derive root_snarked_ledger in
  Ledger_mask.apply root_staged_ledger_mask root_staged_ledger_diff ;
  assert (
    Ledger_hash.equal
      (Ledger_mask.merkle_root root_staged_ledger_mask)
      (Ledger_builder_hash.ledger_hash
         (Consensus.Mechanism.Protocol_state.Blockchain_state
          .ledger_builder_hash root_blockchain_state)) ) ;
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
  let table =
    Coda_base.State_hash.Table.of_alist_exn [(root_hash, root_node)]
  in
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
    if Coda_base.State_hash.equal parent_hash t.root then [hash]
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

(* Adding a transition to the transition frontier is broken into the following steps:
 *   1) create a new node for a transition
 *     a) derive a new mask from the parent mask
 *     b) apply the ledger builder diff to the new mask
 *     c) form the breadcrumb and node records
 *   2) add the node to the table
 *   3) add the successor_hashes entry to the parent node
 *   4) move the root if the path to the new node is longer than the max length
 *     a) calculate the distance from the new node to the parent
 *     b) if the distance is greater than the max length:
 *       I  ) find the immediate successor of the old root in the path to the
 *            longest node and make it the new root
 *       II ) find all successors of the other immediate successors of the old root
 *       III) remove the old root and all of the nodes found in (II) from the table
 *       IV ) merge the old root's merkle mask into the root ledger
 *   5) set the new node as the best tip if the new node has a greater length than
 *      the current best tip
 *)
let add_exn t transition_with_hash =
  let root_node = Hashtbl.find_exn t.table t.root in
  let best_tip_node = Hashtbl.find_exn t.table t.best_tip in
  let transition = With_hash.data transition_with_hash in
  let hash = With_hash.hash transition_with_hash in
  let parent_hash =
    Consensus.Mechanism.Protocol_state.previous_state_hash
      (External_transition.protocol_state transition)
  in
  let parent_node =
    Option.value_exn
      (Hashtbl.find t.table parent_hash)
      ~error:
        (Error.of_exn (Parent_not_found (`Parent parent_hash, `Target hash)))
  in
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
  (* 3 *)
  Hashtbl.set t.table ~key:parent_hash
    ~data:
      {parent_node with successor_hashes= hash :: parent_node.successor_hashes} ;
  (* 4.a *)
  let distance_to_parent = root_node.length - node.length in
  (* 4.b *)
  if distance_to_parent > max_length then (
    (* 4.b.I *)
    let new_root_hash = List.hd_exn (path t node.breadcrumb) in
    (* 4.b.II *)
    let garbage_immediate_successors =
      List.filter root_node.successor_hashes ~f:(fun succ_hash ->
          not (Coda_base.State_hash.equal succ_hash new_root_hash) )
    in
    (* 4.b.III *)
    let garbage =
      t.root
      :: List.bind garbage_immediate_successors ~f:(successor_hashes_rec t)
    in
    t.root <- new_root_hash ;
    List.iter garbage ~f:(Hashtbl.remove t.table) ;
    (* 4.b.IV *)
    Ledger_mask.commit
      (Staged_ledger.ledger_mask
         (Breadcrumb.staged_ledger root_node.breadcrumb)) ) ;
  (* 5 *)
  if node.length > best_tip_node.length then t.best_tip <- hash ;
  node.breadcrumb

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
