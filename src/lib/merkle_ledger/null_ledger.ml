open Core_kernel

module Make
    (Key : Intf.Key)
    (Account : Intf.Account with type key := Key.t)
    (Hash : Intf.Hash with type account := Account.t)
    (Location : Location_intf.S) (Depth : sig
        val depth : int
    end) : sig
  include
    Base_ledger_intf.S
    with module Addr = Location.Addr
    with module Location = Location
    with type key := Key.t
     and type key_set := Key.Set.t
     and type hash := Hash.t
     and type root_hash := Hash.t
     and type account := Account.t

  val create : unit -> t
end = struct
  type t = Core.Uuid.t [@@deriving sexp_of]

  let t_of_sexp _ = failwith "t_of_sexp unimplemented"

  type index = int

  module Location = Location
  module Path = Merkle_path.Make (Hash)

  type path = Path.t

  module Addr = Location.Addr

  let create () = Core.Uuid.create ()

  let remove_accounts_exn _t =
    failwith "remove_accounts_exn: null ledgers cannot be mutated"

  let empty_hash_at_heights depth =
    let empty_hash_at_heights =
      Array.create ~len:(depth + 1) Hash.empty_account
    in
    let rec go i =
      if i <= depth then (
        let h = empty_hash_at_heights.(i - 1) in
        empty_hash_at_heights.(i) <- Hash.merge ~height:(i - 1) h h ;
        go (i + 1) )
    in
    go 1 ; empty_hash_at_heights

  let memoized_empty_hash_at_height = empty_hash_at_heights Depth.depth

  let empty_hash_at_height d = memoized_empty_hash_at_height.(d)

  let merkle_path _t location =
    let location =
      if Location.is_account location then
        Location.Hash (Location.to_path_exn location)
      else location
    in
    assert (Location.is_hash location) ;
    let rec loop k =
      let h = Location.height k in
      if h >= Depth.depth then []
      else
        let sibling_dir = Location.last_direction (Location.to_path_exn k) in
        let hash = empty_hash_at_height h in
        Direction.map sibling_dir ~left:(`Left hash) ~right:(`Right hash)
        :: loop (Location.parent k)
    in
    loop location

  let merkle_root _t = empty_hash_at_height Depth.depth

  let merkle_path_at_addr_exn t addr = merkle_path t (Location.Hash addr)

  let merkle_path_at_index_exn t index =
    merkle_path_at_addr_exn t (Addr.of_int_exn index)

  let index_of_key_exn _t = failwith "index_of_key_exn: null ledgers are empty"

  let set_at_index_exn _t =
    failwith "set_at_index_exn: null ledgers cannot be mutated"

  let get_at_index_exn _t = failwith "get_at_index_exn: null ledgers are empty"

  let set_batch _t = failwith "set_batch: null ledgers cannot be mutated"

  let set _t = failwith "set: null ledgers cannot be mutated"

  let get _t _loc = None

  let get_uuid t = t

  let last_filled _t = None

  let close _t = ()

  let get_or_create_account_exn _t =
    failwith "get_or_create_account_exn: null ledgers cannot be mutated"

  let get_or_create_account _t =
    failwith "get_or_create_account: null ledgers cannot be mutated"

  let location_of_key _t _ = None

  let fold_until _t ~init ~f:_ ~finish = finish init

  let foldi_with_ignored_keys _t _ ~init ~f:_ = init

  let foldi _t ~init ~f:_ = init

  let to_list _t = []

  let make_space_for _t _tot = ()

  let get_all_accounts_rooted_at_exn _t addr =
    List.init (1 lsl Addr.height addr) ~f:(Fn.const Account.empty)

  let set_all_accounts_rooted_at_exn _t =
    failwith "set_all_accounts_rooted_at_exn: null ledgers cannot be mutated"

  let set_inner_hash_at_addr_exn _t =
    failwith "set_inner_hash_at_addr_exn: null ledgers cannot be mutated"

  let get_inner_hash_at_addr_exn _t addr =
    empty_hash_at_height (Addr.height addr)

  let num_accounts _t = 0

  let depth = Depth.depth
end
