open Core_kernel

module Make (Id : sig
  type t [@@deriving sexp, bin_io]
  val (==) : t -> t -> bool
  val to_bits : t -> bool list
end) = struct
  type bucket_elt = Id.t With_peer.t With_timestamp.t [@@deriving sexp]
  type bucket = bucket_elt list [@@deriving sexp]

  type tree_elem =
  | Split of tree_elem * tree_elem
  | Bucket of bucket * Id.t With_peer.t list
  [@@deriving sexp]

  type t =
    { config : Config.t
    ; owner : Id.t
    ; root : tree_elem
    ; peers : Id.t Peer.Table.t
    }

  let create ~config id =
    { config
    ; owner = id
    ; root = Bucket ([], [])
    ; peers = Peer.Table.create ()
    }

  let owner {owner} = owner

  let buckets t = failwith "TODO"

  let to_list t = failwith "TODO"

  let lookup t id = failwith "TODO"

  let findClosest t id k = failwith "TODO"

  let delete t peer = failwith "TODO"
  let insert t node ts = failwith "TODO"
  let handleTimeout t ~now peer = failwith "TODO"
end

