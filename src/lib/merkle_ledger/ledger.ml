open Core

(* SOMEDAY: handle empty wallets *)
module Make
    (Key : Intf.Key) (Account : sig
        type t [@@deriving sexp, bin_io]

        include Intf.Account with type t := t and type key := Key.t
    end)
    (Hash : sig
              type t [@@deriving sexp, hash, compare, bin_io]

              include Intf.Hash with type t := t
            end
            with type account := Account.t) (Depth : sig
        val depth : int
    end) : sig
  include
    Ledger_extras_intf.S
    with type hash := Hash.t
     and type root_hash := Hash.t
     and type account := Account.t
     and type key := Key.t
     and type key_set := Key.Set.t

  val create : unit -> t

  module For_tests : sig
    val get_leaf_hash_at_addr : t -> Addr.t -> Hash.t
  end
end = struct
  include Depth
  module Addr = Merkle_address.Make (Depth)

  type index = int [@@deriving sexp, compare, hash, eq]

  type leafs = int Key.Table.t [@@deriving sexp, bin_io]

  type accounts = Account.t Dyn_array.t [@@deriving sexp, bin_io]

  type nodes = Hash.t Dyn_array.t list [@@deriving sexp, bin_io]

  type tree =
    { leafs: leafs
    ; mutable unset_slots: Int.Set.t
    ; mutable dirty: bool
    ; mutable syncing: bool
    ; mutable nodes_height: int
    ; mutable nodes: nodes
    ; mutable dirty_indices: int list }
  [@@deriving sexp, bin_io]

  type t = {uuid: Uuid.Stable.V1.t; accounts: accounts; tree: tree}
  [@@deriving sexp, bin_io]

  module C : Container.S0 with type t := t and type elt := Account.t =
  Container.Make0 (struct
    module Elt = Account

    type nonrec t = t

    let fold t ~init ~f = Dyn_array.fold_left f init t.accounts

    let iter = `Define_using_fold
  end)

  let to_list = C.to_list

  let fold_until = C.fold_until

  let keys t = C.to_list t |> List.map ~f:Account.public_key |> Key.Set.of_list

  let key_of_index t index =
    if index >= Dyn_array.length t.accounts then None
    else Some (Dyn_array.get t.accounts index |> Account.public_key)

  let iteri t ~f = Dyn_array.iteri f t.accounts

  let foldi_with_ignored_keys t ignored_keys ~init ~f =
    Dyn_array.fold_left
      (fun (i, acc) x ->
        (* won't throw exn because folding over existing indices *)
        let key = Option.value_exn (key_of_index t i) in
        if Key.Set.mem ignored_keys key then (i + 1, acc)
        else (i + 1, f (Addr.of_int_exn i) acc x) )
      (0, init) t.accounts
    |> snd

  let foldi t ~init ~f = foldi_with_ignored_keys t Key.Set.empty ~init ~f

  module Location = struct
    type t = index [@@deriving sexp, compare, hash, eq]
  end

  module Path = Merkle_path.Make (Hash)

  type path = Path.t

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

  let memoized_empty_hash_at_height = empty_hash_at_heights depth

  let empty_hash_at_height d = memoized_empty_hash_at_height.(d)

  (* if depth = N, leafs = 2^N *)
  let create () =
    { uuid= Uuid.create ()
    ; accounts= Dyn_array.create ()
    ; tree=
        { leafs= Key.Table.create ()
        ; unset_slots= Int.Set.empty
        ; dirty= false
        ; syncing= false
        ; nodes_height= 0
        ; nodes= []
        ; dirty_indices= [] } }

  let with_ledger ~f =
    let t = create () in
    f t

  let close _t = failwith "close: not implemented"

  let get_uuid t = t.uuid

  let num_accounts t = Key.Table.length t.tree.leafs

  let location_of_key t key = Hashtbl.find t.tree.leafs key

  let key_of_index_exn t index = Option.value_exn (key_of_index t index)

  let index_of_key_exn t key = Option.value_exn (location_of_key t key)

  let get t index =
    if index >= Dyn_array.length t.accounts then None
    else
      let account = Dyn_array.get t.accounts index in
      Some account

  let index_not_found label index =
    Core.sprintf "Ledger.%s: Index %d not found" label index

  let get_at_index_exn t index =
    get t index
    |> Option.value_exn ~message:(index_not_found "get_at_index_exn" index)

  let replace t index old_key account =
    Dyn_array.set t.accounts index account ;
    Hashtbl.remove t.tree.leafs old_key ;
    Hashtbl.set t.tree.leafs ~key:(Account.public_key account) ~data:index ;
    (t.tree).dirty_indices <- index :: t.tree.dirty_indices

  let allocate t key account =
    let merkle_index = Dyn_array.length t.accounts in
    Dyn_array.add t.accounts account ;
    Hashtbl.set t.tree.leafs ~key ~data:merkle_index ;
    (t.tree).dirty_indices <- merkle_index :: t.tree.dirty_indices ;
    merkle_index

  let last_filled t =
    let merkle_index = Dyn_array.length t.accounts in
    if merkle_index = 0 then None else Some merkle_index

  let get_or_create_account t key account =
    match location_of_key t key with
    | None ->
        let new_index = allocate t key account in
        let max_accounts = 1 lsl Depth.depth in
        if new_index > 1 lsl Depth.depth then
          Error
            (Error.create
               "get_or_create_account: Reached max capacity for number of \
                accounts"
               max_accounts Int.sexp_of_t)
        else Ok (`Added, new_index)
    | Some index -> Ok (`Existed, index)

  let get_or_create_account_exn t key account =
    get_or_create_account t key account
    |> Result.map_error ~f:(fun err -> raise (Error.to_exn err))
    |> Result.ok_exn

  let set_at_index_exn t index account =
    if index < Dyn_array.length t.accounts then
      let old_account = Dyn_array.get t.accounts index in
      replace t index (Account.public_key old_account) account
    else failwith (index_not_found "set_at_index_exn" index)

  let set = set_at_index_exn

  let set_batch t indexes_and_accounts =
    List.iter indexes_and_accounts ~f:(fun (index, account) ->
        set t index account )

  let extend_tree t =
    let leafs = Dyn_array.length t.accounts in
    if leafs <> 0 then (
      let target_height = Int.max 1 (Int.ceil_log2 leafs) in
      let current_height = t.tree.nodes_height in
      let additional_height = target_height - current_height in
      (t.tree).nodes_height <- t.tree.nodes_height + additional_height ;
      (t.tree).nodes
      <- List.concat
           [ t.tree.nodes
           ; List.init additional_height ~f:(fun _ -> Dyn_array.create ()) ] ;
      List.iteri t.tree.nodes ~f:(fun i nodes ->
          let length = Int.pow 2 (t.tree.nodes_height - 1 - i) in
          let new_elems = length - Dyn_array.length nodes in
          Dyn_array.append
            (Dyn_array.init new_elems (fun _ -> empty_hash_at_height (i + 1)))
            nodes ) )

  let rec recompute_layers curr_height get_prev_hash layers dirty_indices =
    match layers with
    | [] -> ()
    | curr :: layers ->
        let get_curr_hash =
          let n = Dyn_array.length curr in
          fun i ->
            if i < n then Dyn_array.get curr i
            else empty_hash_at_height curr_height
        in
        List.iter dirty_indices ~f:(fun i ->
            Dyn_array.set curr i
              (Hash.merge ~height:(curr_height - 1)
                 (get_prev_hash (2 * i))
                 (get_prev_hash ((2 * i) + 1))) ) ;
        let dirty_indices =
          List.dedup_and_sort ~compare:Int.compare
            (List.map dirty_indices ~f:(fun x -> x lsr 1))
        in
        recompute_layers (curr_height + 1) get_curr_hash layers dirty_indices

  let get_leaf_hash t i =
    if i < Dyn_array.length t.accounts then
      Hash.hash_account (Dyn_array.get t.accounts i)
    else Hash.empty_account

  let recompute_tree t =
    if not (List.is_empty t.tree.dirty_indices) then (
      extend_tree t ;
      (t.tree).dirty <- false ;
      let layer_dirty_indices =
        Int.Set.to_list
          (Int.Set.of_list (List.map t.tree.dirty_indices ~f:(fun x -> x / 2)))
      in
      recompute_layers 1 (get_leaf_hash t) t.tree.nodes layer_dirty_indices ;
      (t.tree).dirty_indices <- [] )

  let remove_accounts_exn t keys =
    let len = List.length keys in
    if len <> 0 then (
      assert (not t.tree.syncing) ;
      let indices =
        List.map keys ~f:(fun k -> index_of_key_exn t k)
        |> List.sort ~compare:Int.compare
      in
      let least = List.hd_exn indices in
      assert (least = num_accounts t - len) ;
      List.iter keys ~f:(fun k -> Key.Table.remove t.tree.leafs k) ;
      Dyn_array.delete_range t.accounts least len ;
      (* TODO: fixup hashes in a less terrible way *)
      (t.tree).dirty_indices <- List.init least ~f:(fun i -> i) ;
      (t.tree).nodes_height <- 0 ;
      (t.tree).nodes <- [] ;
      recompute_tree t )

  let merkle_root t =
    recompute_tree t ;
    if not (Int.Set.is_empty t.tree.unset_slots) then
      failwithf !"%{sexp:Int.Set.t} remain unset" t.tree.unset_slots () ;
    let height = t.tree.nodes_height in
    let base_root =
      match List.last t.tree.nodes with
      | None -> Hash.empty_account
      | Some a -> Dyn_array.get a 0
    in
    let rec go i hash =
      if i = 0 then hash
      else
        let height = depth - i in
        let hash = Hash.merge ~height hash (empty_hash_at_height height) in
        go (i - 1) hash
    in
    go (depth - height) base_root

  let merkle_path_at_index_exn t index =
    if index >= Dyn_array.length t.accounts then
      failwith (index_not_found "merkle_path_at_index_exn" index)
    else (
      recompute_tree t ;
      let rec go height addr layers acc =
        match layers with
        | [] -> (acc, height)
        | curr :: layers ->
            let is_left = addr mod 2 = 0 in
            let hash =
              let sibling = addr lxor 1 in
              if sibling < Dyn_array.length curr then
                Dyn_array.get curr sibling
              else empty_hash_at_height height
            in
            go (height + 1) (addr lsr 1) layers
              ((if is_left then `Left hash else `Right hash) :: acc)
      in
      let leaf_hash_idx = index lxor 1 in
      let leaf_hash =
        if leaf_hash_idx >= Hashtbl.length t.tree.leafs then Hash.empty_account
        else Hash.hash_account (Dyn_array.get t.accounts leaf_hash_idx)
      in
      let is_left = index mod 2 = 0 in
      let non_root_nodes = List.take t.tree.nodes (depth - 1) in
      let base_path, base_path_height =
        go 1 (index lsr 1) non_root_nodes
          [(if is_left then `Left leaf_hash else `Right leaf_hash)]
      in
      List.rev_append base_path
        (List.init (depth - base_path_height) ~f:(fun i ->
             `Left (empty_hash_at_height (i + base_path_height)) )) )

  let merkle_path = merkle_path_at_index_exn

  module For_tests = struct
    let get_leaf_hash_at_addr t addr = get_leaf_hash t (Addr.to_int addr)
  end

  (* FIXME: Probably this will cause an error *)
  let merkle_path_at_addr_exn t a =
    assert (Addr.depth a = Depth.depth - 1) ;
    merkle_path_at_index_exn t (Addr.to_int a)

  let set_at_addr_exn t addr acct =
    assert (Addr.depth addr = Depth.depth - 1) ;
    set_at_index_exn t (Addr.to_int addr) acct

  let complete_with_empties hash start_height result_height =
    let rec go cur_empty prev_hash height =
      if height = result_height then prev_hash
      else
        let cur = Hash.merge ~height prev_hash cur_empty in
        let next_empty = Hash.merge ~height cur_empty cur_empty in
        go next_empty cur (height + 1)
    in
    go (empty_hash_at_height start_height) hash start_height

  let get_inner_hash_at_addr_exn t a =
    let adepth = Addr.depth a in
    assert (adepth < depth) ;
    let height = Addr.height a in
    let index = Addr.to_int a in
    let layer = List.nth t.tree.nodes (height - 1) in
    let layer_len = Option.value_map ~f:DynArray.length ~default:0 layer in
    recompute_tree t ;
    if height < t.tree.nodes_height && index < layer_len then
      DynArray.get (Option.value_exn layer) index
    else if index = 0 && not (t.tree.nodes_height = 0) then
      complete_with_empties
        (DynArray.get (List.last_exn t.tree.nodes) 0)
        t.tree.nodes_height height
    else empty_hash_at_height height

  let set_inner_hash_at_addr_exn t a hash =
    let path_length = Addr.depth a in
    assert (path_length < depth) ;
    (t.tree).dirty <- true ;
    let l = List.nth_exn t.tree.nodes (depth - path_length - 1) in
    let index = Addr.to_int a in
    DynArray.set l index hash

  let make_space_for t total =
    let len = Dyn_array.length t.accounts in
    if total > len then
      (t.tree).unset_slots
      <- Int.Set.union t.tree.unset_slots
           (Int.Set.of_list
              (List.init (total - len) ~f:(fun i ->
                   Dyn_array.add t.accounts Account.empty ;
                   len + i )))

  let set_all_accounts_rooted_at_exn t a accounts =
    let height = depth - Addr.depth a in
    let first_index = Addr.to_int a lsl height in
    assert (List.length accounts <= 1 lsl height) ;
    make_space_for t (first_index + List.length accounts) ;
    List.iteri accounts ~f:(fun i a ->
        let new_index = first_index + i in
        if Int.Set.mem t.tree.unset_slots new_index then (
          replace t new_index Key.empty a ;
          (t.tree).unset_slots <- Int.Set.remove t.tree.unset_slots new_index )
        else set_at_index_exn t new_index a )

  let location_of_addr = Addr.to_int

  include Util.Make (struct
    module Location = Location
    module Account = Account
    module Addr = Addr

    module Base = struct
      type nonrec t = t

      let get = get
    end

    let location_of_addr = location_of_addr
  end)
end
