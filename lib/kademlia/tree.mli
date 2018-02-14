open Core_kernel

module Make (Id : sig
  type t [@@deriving sexp, bin_io]
  val (==) : t -> t -> bool
  val to_bits : t -> bool list
end) : sig
  type t

  type bucket_elt = Id.t With_peer.t With_timestamp.t [@@deriving sexp]
  type bucket = bucket_elt list [@@deriving sexp]

  (* Create a tree owned by Id.t *)
  val create : config:Config.t -> Id.t -> t
  (* Extract the owner of this tree *)
  val owner : t -> Id.t

  val lookup : t -> Id.t -> Id.t With_peer.t option

  (* Return the buckets sorted by distance to the owner *)
  val buckets : t -> bucket list

  (* Return all the data in the buckets of the tree *)
  val to_list : t -> bucket_elt list

  (* Find the k closest nodes to some id *)
  val findClosest : t -> Id.t -> int -> Id.t With_peer.t list

  (* Mutation *)

  (* Delete a peer *)
  val delete : t -> Peer.t -> unit
  (* Insert an identified peer *)
  val insert : t -> Id.t With_peer.t -> Time.t -> unit
  (* Punish a peer for timing out *)
  val handleTimeout : t -> now:Time.t -> Peer.t -> [`Don't_ping_again | `Ping_again_okay]
end

