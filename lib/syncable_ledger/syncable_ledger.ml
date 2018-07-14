open Core
open Async_kernel

module type Addr_intf = sig
  type t [@@deriving sexp, bin_io, hash, compare]

  include Hashable.S with type t := t

  val depth : t -> int

  val parent : t -> t option

  val parent_exn : t -> t

  val child : t -> [`Left | `Right] -> t option

  val child_exn : t -> [`Left | `Right] -> t

  val unpeel : t -> ([`Left | `Right] * t) option

  val unpeel_exn : t -> [`Left | `Right] * t

  val root : t
end

module type Hash_intf = sig
  type hash [@@deriving sexp, hash, compare, bin_io]

  val empty_hash : hash

  val merge : height:int -> hash -> hash -> hash
end

module type Merkle_tree_intf = sig
  type hash [@@deriving bin_io, compare]

  type account [@@deriving bin_io]

  type key

  type addr

  type node

  type t

  type path

  val depth : int

  val merkle_path_at_addr_exn : t -> addr -> path

  val get_inner_hash_at_addr_exn : t -> addr -> hash

  val set_inner_hash_at_addr_exn : t -> addr -> hash -> unit

  val extend_with_empty_to_fit : t -> int -> unit

  val set_all_entries_rooted_at : t -> addr -> account list -> unit

  val merkle_root : t -> hash

  val set_syncing : t -> unit

  val clear_syncing : t -> unit
end

module type S = sig
  type t

  type merkle_tree

  type merkle_path

  type hash

  type addr

  type diff

  type account

  type key

  type index = int

  type answer =
    | Has_hash of addr * hash
    | Contents_are of addr * account list
    | Num_accounts of int
  [@@deriving bin_io]

  type query = What_hash of addr | What_contents of addr | Num_accounts
  [@@deriving bin_io]

  val create : merkle_tree -> hash -> t

  val answer_writer : t -> (hash * answer) Linear_pipe.Writer.t

  val query_reader : t -> (hash * query) Linear_pipe.Reader.t

  val destroy : t -> unit

  val new_goal : t -> hash -> unit

  val wait_until_valid : t -> hash -> [`Ok | `Target_changed] Deferred.t

  val apply_or_queue_diff : t -> diff -> unit

  val merkle_path_at_addr : t -> addr -> merkle_path Or_error.t

  val get_account_at_addr : t -> addr -> account Or_error.t
end

module type Validity_intf = sig
  type t

  type addr

  val create : int -> t

  val mark_known_good : t -> addr -> unit

  val fully_valid : t -> bool
end

(*
For a given addr, there are three possibilities:

1. the current value in the ledger at addr is already fine. in this case, we
  mark_known_good that addr.
2. the current value in the ledger is bad. in tihs case, we do nothing and
  recurse.
3. we're down to a height=N subtree and fetch the child accounts, then
  mark_known_good the addr of the root of the subtree

We want all_valid when every leaf of the tree is `Valid
*)

module Valid (Addr : Addr_intf) :
  Validity_intf with type addr := Addr.t =
struct
  type tree = Leaf of [`Valid | `Unknown] | Node of tree ref * tree ref

  type t = tree ref

  let create i = ref (Leaf `Unknown)

  let unpeel_all a =
    let rec unpeel_aux a acc =
      match Addr.unpeel a with
      | Some (d, a') -> unpeel_aux a' (d :: acc)
      | None -> acc
    in
    List.rev (unpeel_aux a [])

  let mark_known_good t a =
    let dirs = unpeel_all a in
    let rec mark_helper node dir =
      match dir with
      | d :: ds -> (
          let accessor = match d with `Left -> fst | `Right -> snd in
          match !node with
          (* sanity assert: we shouldn't ever be recursing under valid parts of the tree *)
          | Leaf v ->
              assert (v = `Unknown) ;
              node := Node (ref !node, ref !node)
          | Node (l, r) -> mark_helper (accessor (l, r)) ds )
      | [] ->
        match !node with
        | Leaf `Unknown -> node := Leaf `Valid
        | _ ->
            failwith
              "sanity: by the time we get here, we should be at a Leaf `Unknown"
    in
    mark_helper t dirs

  let rec fully_valid t =
    match !t with
    | Leaf `Valid -> true
    | Leaf `Unknown -> false
    | Node (l, r) -> fully_valid l && fully_valid r
end

(*
Note: while syncing, the underlying ledger is in an
indeterminate state. We're mutating hashes at internal
nodes without updating their children. In fact, we
don't even set all the hashes for the internal nodes!
(When we hit a height=N subtree, we don't do anything
with the hashes in the bottomost N-1 internal nodes).
We rely on clear_syncing to recompute the hashes and
do any other fixup necessary.
*)

module Make
    (Addr : Addr_intf) (Key : sig
        type t [@@deriving bin_io]
    end)
    (Valid : Validity_intf with type addr := Addr.t) (Account : sig
        type t [@@deriving bin_io]
    end)
    (Hash : Hash_intf)
    (MT : Merkle_tree_intf
          with type hash := Hash.hash
           and type addr := Addr.t
           and type key := Key.t) :
  S
  with type merkle_tree := MT.t
   and type hash := Hash.hash
   and type addr := Addr.t
   and type merkle_path := MT.path
   and type account := MT.account
   and type key := Key.t =
struct
  type account = unit

  type diff = unit

  type index = int

  type answer =
    | Has_hash of Addr.t * Hash.hash
    | Contents_are of Addr.t * MT.account list
    | Num_accounts of int
    (* idea: make this verifiable by including the merkle path to the rightmost account, and verify that
       filling in empty hashes for the rest amounts to the correct hash. *)
  [@@deriving bin_io]

  type query = What_hash of Addr.t | What_contents of Addr.t | Num_accounts
  [@@deriving bin_io]

  type t =
    { mutable desired_root: Hash.hash
    ; tree: MT.t
    ; validity: Valid.t
    ; answers: (Hash.hash * answer) Linear_pipe.Reader.t
    ; answer_writer: (Hash.hash * answer) Linear_pipe.Writer.t
    ; queries: (Hash.hash * query) Linear_pipe.Writer.t
    ; query_reader: (Hash.hash * query) Linear_pipe.Reader.t
    ; waiting_parents: (Addr.t * Hash.hash) list Addr.Table.t
    ; mutable validity_listeners: [`Ok | `Target_changed] Ivar.t list }

  let create mt h =
    let qr, qw = Linear_pipe.create () in
    let ar, aw = Linear_pipe.create () in
    let t =
      { desired_root= h
      ; tree= mt
      ; validity= Valid.create MT.depth
      ; answers= ar
      ; answer_writer= aw
      ; queries= qw
      ; query_reader= qr
      ; waiting_parents= Addr.Table.create ()
      ; validity_listeners= [] }
    in
    let r = Addr.root in
    let lr = Addr.child_exn r `Left in
    let rr = Addr.child_exn r `Right in
    Linear_pipe.write_without_pushback t.queries (h, What_hash lr) ;
    Linear_pipe.write_without_pushback t.queries (h, What_hash rr) ;
    t

  let answer_writer t = t.answer_writer

  let query_reader t = t.query_reader

  let hash_eq h1 h2 = Hash.compare_hash h1 h2 = 0

  let add_child_hash_to :
         t
      -> Addr.t
      -> Hash.hash
      -> [`Good of Addr.t list | `More | `Hash_mismatch] =
   fun t child_addr h ->
    (* lots of _exn called on attacker data. it's not clear how to handle these regardless *)
    let parent = Addr.parent_exn child_addr in
    Addr.Table.add_multi t.waiting_parents parent (child_addr, h) ;
    let l = Addr.Table.find_multi t.waiting_parents parent in
    match l with
    | [(l1, h1); (l2, h2)] ->
        if
          hash_eq
            (Hash.merge ~height:(Addr.depth l1) h1 h2)
            (MT.get_inner_hash_at_addr_exn t.tree parent)
        then (
          Addr.Table.remove t.waiting_parents parent ;
          let children_to_verify =
            List.rev_append
              ( if hash_eq (MT.get_inner_hash_at_addr_exn t.tree l1) h1 then (
                  Valid.mark_known_good t.validity l1 ;
                  [] )
              else [l1] )
              ( if hash_eq (MT.get_inner_hash_at_addr_exn t.tree l2) h2 then (
                  Valid.mark_known_good t.validity l2 ;
                  [] )
              else [l2] )
          in
          `Good children_to_verify )
        else `Hash_mismatch
    | _ -> `More

  let subtree_height = 3

  let all_done t res =
    MT.clear_syncing t.tree ;
    if not (hash_eq (MT.merkle_root t.tree) t.desired_root) then
      failwith "We finished syncing, but made a mistake somewhere :("
    else List.iter t.validity_listeners ~f:(fun i -> Ivar.fill i `Ok) ;
    t.validity_listeners <- [] ;
    res

  (* Assumption: only ever one answer is received for a given query
     When violated, waiting_parents can get junk added to it, which
     will stick around until the SL is destroyed, or else cause a
     node to never be verified *)
  let main_loop t =
    let handle_answer (root_hash, a) =
      if root_hash <> t.desired_root then return ()
      else
        let res =
          match a with
          | Has_hash (addr, h') -> (
            match add_child_hash_to t addr h' with
            | `Good children_to_verify ->
                Deferred.List.iter children_to_verify ~f:(fun addr ->
                    if Addr.depth addr = MT.depth - subtree_height then
                      Linear_pipe.write t.queries
                        (t.desired_root, What_contents addr)
                    else
                      let%bind () =
                        Linear_pipe.write t.queries
                          ( t.desired_root
                          , What_hash (Addr.child_exn addr `Left) )
                      in
                      Linear_pipe.write t.queries
                        (t.desired_root, What_hash (Addr.child_exn addr `Right))
                )
            | `More -> return () (* wait for the other answer to come in *)
            | `Hash_mismatch ->
                (* just ask again for both children of the parent?
             this is the only case where we can't immediately
             pin blame on a single node. *)
                failwith "figure out how to handle peers lying" )
          | Contents_are (addr, leafs) ->
              (* TODO: verify the hash matches what we expect *)
              MT.set_all_entries_rooted_at t.tree addr leafs ;
              Valid.mark_known_good t.validity addr ;
              return ()
          | Num_accounts n ->
              MT.extend_with_empty_to_fit t.tree n ;
              return ()
        in
        if Valid.fully_valid t.validity then all_done t res else res
    in
    Linear_pipe.iter t.answers ~f:handle_answer

  let destroy t =
    Linear_pipe.close_read t.answers ;
    Linear_pipe.close_read t.query_reader

  let new_goal t h =
    List.iter t.validity_listeners ~f:(fun i -> Ivar.fill i `Target_changed) ;
    t.validity_listeners <- [] ;
    t.desired_root <- h

  let wait_until_valid t h =
    if not (hash_eq h t.desired_root) then return `Target_changed
    else
      let iv = Ivar.create () in
      t.validity_listeners <- iv :: t.validity_listeners ;
      Ivar.read iv

  let apply_or_queue_diff t d =
    (* Need some interface for the diffs, not sure the layering is right here. *)
    failwith "todo"

  let merkle_path_at_addr = failwith "no"

  let get_account_at_addr = failwith "no"
end
