open Core
open Async_kernel

(*
module type Addr_intf = sig
  type t

  include Hashable.S with type t := t

  val depth : t -> int

  val parent : t -> t

  val child : t -> [`Left | `Right] -> t
end

module type Merkle_tree_intf = sig
  type hash

  type leaf

  type key

  type addr

  type node

  type t

  type dir = [`Left | `Right]

  val merge : hash -> hash -> hash

  val hash_eq : hash -> hash -> bool

  val children_of : addr -> node list

  val root_addr : addr

  val hash_at_addr : addr -> hash

  val set_leaf : t -> addr -> leaf -> unit
  val set_inner_exn : t -> addr -> hash -> unit
end
*)
module type S = sig
  type t

  type merkle_tree

  type merkle_path

  type hash

  type addr

  type leaf

  type diff

  type answer =
    | Has_hash of addr * hash
    | Contents_are of addr * leaf list
    [@@deriving bin_io]

  type query =
    | What_hash of addr
    | What_contents of addr
    [@@deriving bin_io]

  val create : merkle_tree -> hash -> t

  val answer_writer : t -> (hash * answer) Linear_pipe.Writer.t

  val query_reader : t -> (hash * query) Linear_pipe.Reader.t

  val interrupt : t -> unit

  val new_goal : t -> hash -> unit

  val wait_until_valid : t -> hash -> [`Ok | `Target_changed] Deferred.t

  val apply_or_queue_diff : t -> diff -> unit

  val merkle_path_to_addr : t -> addr -> merkle_path Or_error.t

  val get_leaf_at_addr : t -> addr -> leaf Or_error.t
end
(*
module Sync (Addr : Addr_intf) (MT : Merkle_tree_intf with type addr := Addr.t) :
  S
  with type merkle_tree := MT.t
   and type hash := MT.hash
   and type addr := Addr.t
   and type leaf := MT.leaf =
struct
  type t =
    { desired_root: MT.hash
    ; current_tree: MT.t
    ; mutable to_fetch: Addr.t list
    ; mutable to_verify: (Addr.t * MT.hash) list
    ; waiting_parents: (Addr.t * MT.hash) list Addr.Table.t }

  let _left : Addr.t -> Addr.t * MT.hash =
   fun a ->
    let a = Addr.child a `Left in
    (a, MT.hash_at_addr a)

  let _right : Addr.t -> Addr.t * MT.hash =
   fun a ->
    let a = Addr.child a `Right in
    (a, MT.hash_at_addr a)

  (* NOTE: mutates the merkle tree it's given while syncing! *)
  let create : MT.t -> MT.hash -> t =
   fun mt h ->
    let to_verify = [_left MT.root_addr; _right MT.root_addr] in
    { desired_root= h
    ; current_tree= mt
    ; to_fetch= []
    ; to_verify
    ; waiting_parents= Addr.Table.create () }

  let add_child_hash_to : t -> Addr.t -> MT.hash -> [`Ok | `Hash_mismatch] =
   fun t child_addr h ->
    let parent = Addr.parent child_addr in
    Addr.Table.add_multi t.waiting_parents parent (child_addr, h) ;
    let l = Addr.Table.find_multi t.waiting_parents parent in
    match l with
    | [(l1, h1); (l2, h2)] ->
        if MT.hash_eq (MT.merge h1 h2) (MT.hash_at_addr parent) then (
          Addr.Table.remove t.waiting_parents parent ;
          `Ok )
        else `Hash_mismatch
    | _ -> `Ok

  (* track the provenance of req/resps and blacklist?
     but, we don't know which peer is lying until we ask someone else *)
  let to_verify : t -> bool * (Addr.t * MT.hash) list =
   fun t ->
    ( List.is_empty t.to_fetch
    , let tv = t.to_verify in
      t.to_verify <- [] ;
      tv )

  let verify_step : t -> (Addr.t * [`Ok | `Bad of MT.hash]) list -> bool =
   fun t claimed_truth ->
    List.fold claimed_truth ~init:false ~f:(fun acc (a, i) ->
        let parent = Addr.parent a in
        match i with
        | `Ok -> (
          match add_child_hash_to t (Addr.parent a) (MT.hash_at_addr a) with
          | `Ok -> acc (* TODO: build up validity tree *)
          | `Hash_mismatch ->
              failwith "figure out how to handle a peer lying to us" )
        | `Bad real_hash ->
          match add_child_hash_to t (Addr.parent a) real_hash with
          | `Ok ->
              t.to_verify
              <- List.append t.to_verify [_left parent; _right parent] ;
              true
          | `Hash_mismatch ->
              failwith "figure out how to handle a peer lying to us" )

  let to_fetch : t -> Addr.t list =
   fun t ->
    let tf = t.to_fetch in
    t.to_fetch <- [] ;
    tf

  let fetch_step : t -> (Addr.t * MT.leaf) list -> unit =
   fun t new_leafs ->
    List.iter new_leafs ~f:(fun (a, l) -> MT.set_at_addr t.current_tree a l)

  let finish : t -> MT.t option =
   fun t ->
    if
      List.is_empty t.to_fetch && List.is_empty t.to_verify
      && Addr.Table.is_empty t.waiting_parents
    then Some t.current_tree
    else None
end
*)
