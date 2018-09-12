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
  include Ledger_intf.S
          with type hash := Hash.t
           and type account := Account.t
           and type key := Key.t

  module For_tests : sig
    val get_leaf_hash_at_addr : t -> Addr.t -> Hash.t
  end
end = struct
  include Depth
  module Addr = Merkle_address.Make (Depth)

  type entry = {merkle_index: int; account: Account.t}
  [@@deriving sexp, bin_io]

  type accounts = entry Key.Table.t [@@deriving sexp, bin_io]

  type index = int

  type leafs = Key.t Dyn_array.t [@@deriving sexp, bin_io]

  type nodes = Hash.t Dyn_array.t list [@@deriving sexp, bin_io]

  type tree =
    { leafs: leafs
    ; mutable dirty: bool
    ; mutable syncing: bool
    ; mutable nodes_height: int
    ; mutable nodes: nodes
    ; mutable dirty_indices: int list }
  [@@deriving sexp, bin_io]

  type t = {accounts: accounts; tree: tree} [@@deriving sexp, bin_io]

  let copy t =
    let copy_tree tree =
      { leafs= Dyn_array.copy tree.leafs
      ; dirty= tree.dirty
      ; syncing= false
      ; nodes_height= tree.nodes_height
      ; nodes= List.map tree.nodes ~f:Dyn_array.copy
      ; dirty_indices= tree.dirty_indices }
    in
    {accounts= Key.Table.copy t.accounts; tree= copy_tree t.tree}

  module Path = Merkle_path.Make (Hash)

  let create_account_table () = Key.Table.create ()

  let empty_hash_at_heights depth =
    let empty_hash_at_heights = Array.create ~len:(depth + 1) Hash.empty in
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
    { accounts= create_account_table ()
    ; tree=
        { leafs= Dyn_array.create ()
        ; dirty= false
        ; syncing= false
        ; nodes_height= 0
        ; nodes= []
        ; dirty_indices= [] } }

  let num_accounts t = Key.Table.length t.accounts

  let key_of_index t index =
    if index >= Dyn_array.length t.tree.leafs then None
    else Some (Dyn_array.get t.tree.leafs index)

  let index_of_key t key =
    Option.map (Hashtbl.find t.accounts key) ~f:(fun {merkle_index; _} ->
        merkle_index )

  let key_of_index_exn t index = Option.value_exn (key_of_index t index)

  let index_of_key_exn t key = Option.value_exn (index_of_key t key)

  let get t key =
    Option.map (Hashtbl.find t.accounts key) ~f:(fun entry -> entry.account)

  let index_not_found label index =
    failwithf "Ledger.%s: Index %d not found" label index ()

  let get_at_index t index =
    if index >= Dyn_array.length t.tree.leafs then `Index_not_found
    else
      let key = Dyn_array.get t.tree.leafs index in
      `Ok (Hashtbl.find_exn t.accounts key).account

  let get_at_index_exn t index =
    match get_at_index t index with
    | `Ok account -> account
    | `Index_not_found -> index_not_found "get_at_index_exn" index

  let set t key account =
    match Hashtbl.find t.accounts key with
    | None ->
        let merkle_index = Dyn_array.length t.tree.leafs in
        Hashtbl.set t.accounts ~key ~data:{merkle_index; account} ;
        Dyn_array.add t.tree.leafs key ;
        (t.tree).dirty_indices <- merkle_index :: t.tree.dirty_indices
    | Some entry ->
        Hashtbl.set t.accounts ~key
          ~data:{merkle_index= entry.merkle_index; account} ;
        (t.tree).dirty_indices <- entry.merkle_index :: t.tree.dirty_indices

  let update t key ~f =
    match Hashtbl.find t.accounts key with
    | None ->
        let merkle_index = Dyn_array.length t.tree.leafs in
        Hashtbl.set t.accounts ~key ~data:{merkle_index; account= f None} ;
        Dyn_array.add t.tree.leafs key ;
        (t.tree).dirty_indices <- merkle_index :: t.tree.dirty_indices
    | Some {merkle_index; account} ->
        Hashtbl.set t.accounts ~key
          ~data:{merkle_index; account= f (Some account)} ;
        (t.tree).dirty_indices <- merkle_index :: t.tree.dirty_indices

  let set_at_index t index account =
    let leafs = t.tree.leafs in
    if index < Dyn_array.length leafs then (
      let key = Dyn_array.get leafs index in
      Hashtbl.set t.accounts ~key ~data:{merkle_index= index; account} ;
      (t.tree).dirty_indices <- index :: t.tree.dirty_indices ;
      `Ok )
    else `Index_not_found

  let set_at_index_exn t index account =
    match set_at_index t index account with
    | `Ok -> ()
    | `Index_not_found -> index_not_found "set_at_index_exn" index

  let extend_tree tree =
    let leafs = Dyn_array.length tree.leafs in
    if leafs <> 0 then (
      let target_height = Int.max 1 (Int.ceil_log2 leafs) in
      let current_height = tree.nodes_height in
      let additional_height = target_height - current_height in
      tree.nodes_height <- tree.nodes_height + additional_height ;
      tree.nodes
      <- List.concat
           [ tree.nodes
           ; List.init additional_height ~f:(fun _ -> Dyn_array.create ()) ] ;
      List.iteri tree.nodes ~f:(fun i nodes ->
          let length = Int.pow 2 (tree.nodes_height - 1 - i) in
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
    if i < Dyn_array.length t.tree.leafs then
      Hash.hash_account
        (Hashtbl.find_exn t.accounts (Dyn_array.get t.tree.leafs i)).account
    else Hash.empty

  let recompute_tree t =
    if not (List.is_empty t.tree.dirty_indices) then (
      extend_tree t.tree ;
      (t.tree).dirty <- false ;
      let layer_dirty_indices =
        Int.Set.to_list
          (Int.Set.of_list (List.map t.tree.dirty_indices ~f:(fun x -> x / 2)))
      in
      recompute_layers 1 (get_leaf_hash t) t.tree.nodes layer_dirty_indices ;
      (t.tree).dirty_indices <- [] )

  let merkle_root t =
    recompute_tree t ;
    let height = t.tree.nodes_height in
    let base_root =
      match List.last t.tree.nodes with
      | None -> Hash.empty
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

  let hash t = Hash.hash (merkle_root t)

  let hash_fold_t state t = Ppx_hash_lib.Std.Hash.fold_int state (hash t)

  let compare t t' = Hash.compare (merkle_root t) (merkle_root t')

  let merkle_path t key =
    recompute_tree t ;
    Option.map (Hashtbl.find t.accounts key) ~f:(fun entry ->
        let addr0 = entry.merkle_index in
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
        let leaf_hash_idx = addr0 lxor 1 in
        let leaf_hash =
          if leaf_hash_idx >= Dyn_array.length t.tree.leafs then Hash.empty
          else
            Hash.hash_account
              (Hashtbl.find_exn t.accounts
                 (Dyn_array.get t.tree.leafs leaf_hash_idx))
                .account
        in
        let is_left = addr0 mod 2 = 0 in
        let non_root_nodes = List.take t.tree.nodes (depth - 1) in
        let base_path, base_path_height =
          go 1 (addr0 lsr 1) non_root_nodes
            [(if is_left then `Left leaf_hash else `Right leaf_hash)]
        in
        List.rev_append base_path
          (List.init (depth - base_path_height) ~f:(fun i ->
               `Left (empty_hash_at_height (i + base_path_height)) )) )

  let merkle_path_at_index t index =
    match Option.(key_of_index t index >>= merkle_path t) with
    | None -> `Index_not_found
    | Some path -> `Ok path

  let merkle_path_at_index_exn t index =
    match merkle_path_at_index t index with
    | `Ok path -> path
    | `Index_not_found -> index_not_found "merkle_path_at_index_exn" index

  let extend_with_empty_to_fit t new_size =
    let tree = t.tree in
    let len = DynArray.length tree.leafs in
    if new_size > len then
      DynArray.append tree.leafs
        (DynArray.init (new_size - len) (fun _ -> Key.empty)) ;
    recompute_tree t

  let to_index a =
    List.foldi
      (List.rev @@ Addr.dirs_from_root a)
      ~init:0
      ~f:(fun i acc dir -> acc lor (Direction.to_int dir lsl i))

  module For_tests = struct
    let get_leaf_hash_at_addr t addr = get_leaf_hash t (to_index addr)
  end

  (* FIXME: Probably this will cause an error *)
  let merkle_path_at_addr_exn t a =
    assert (Addr.depth a = Depth.depth - 1) ;
    merkle_path_at_index_exn t (to_index a)

  let set_at_addr_exn t addr acct =
    assert (Addr.depth addr = Depth.depth - 1) ;
    set_at_index_exn t (to_index addr) acct

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
    let index = to_index a in
    recompute_tree t ;
    if height < t.tree.nodes_height && index < num_accounts t then
      let l = List.nth_exn t.tree.nodes (depth - adepth - 1) in
      DynArray.get l index
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
    let index = to_index a in
    DynArray.set l index hash

  let set_all_accounts_rooted_at_exn t a accounts =
    let height = depth - Addr.depth a in
    let first_index = to_index a lsl height in
    let count = min (1 lsl height) (num_accounts t - first_index) in
    assert (List.length accounts = count) ;
    List.iteri accounts ~f:(fun i a ->
        let pk = Account.public_key a in
        let entry = {merkle_index= first_index + i; account= a} in
        (t.tree).dirty_indices <- (first_index + i) :: t.tree.dirty_indices ;
        Key.Table.set t.accounts ~key:pk ~data:entry ;
        Dyn_array.set t.tree.leafs (first_index + i) pk )

  let get_all_accounts_rooted_at_exn t a =
    let height = depth - Addr.depth a in
    let first_index = to_index a lsl height in
    let count = min (1 lsl height) (num_accounts t - first_index) in
    let subarr = Dyn_array.sub t.tree.leafs first_index count in
    Dyn_array.to_list
      (Dyn_array.map
         (fun key -> (Key.Table.find_exn t.accounts key).account)
         subarr)
end
