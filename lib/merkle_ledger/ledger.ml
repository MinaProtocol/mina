open Core_kernel
open Coda_spec

module type Inputs_intf = sig
  module Depth : Ledger_intf.Depth.S
  module Account : Account_intf.S
  module Root_hash : Ledger_hash_intf.S
  module Hash : Ledger_intf.Hash.S
    with module Account = Account
end

(* SOMEDAY: handle empty wallets *)
module Make
    (Inputs : Inputs_intf)
  : Ledger_intf.Base_binable.S
      with module Account = Inputs.Account
       and module Root_hash = Inputs.Root_hash
       and module Hash = Inputs.Hash =
struct
  include Inputs
  module Compressed_public_key = Account.Compressed_public_key
  module Path = Path.Make (Hash)
  module Address = Address.Make (Depth)

  type error =
    | Account_location_not_found
    | Out_of_leaves
    | Malformed_database
  [@@deriving sexp]

  exception Error_exception of error

  let depth = Depth.t

  type index = int

  type leaves = int Compressed_public_key.Table.t [@@deriving sexp, bin_io]

  type accounts = Account.t Dyn_array.t [@@deriving sexp, bin_io]

  type nodes = Hash.t Dyn_array.t list [@@deriving sexp, bin_io]

  type tree =
    { leaves: leaves
    ; mutable unset_slots: Int.Set.t
    ; mutable dirty: bool
    ; mutable syncing: bool
    ; mutable nodes_height: int
    ; mutable nodes: nodes
    ; mutable dirty_indices: int list }
  [@@deriving sexp, bin_io]

  type t = {accounts: accounts; tree: tree} [@@deriving sexp, bin_io]

  module C :
    Container.S0 with type t := t and type elt := Account.t =
  Container.Make0 (struct
    module Elt = Account

    type nonrec t = t

    let fold t ~init ~f = Dyn_array.fold_left f init t.accounts

    let iter = `Define_using_fold
  end)

  let empty_account_hash = Hash.of_account Account.empty

  let to_list = C.to_list

  module Location = struct
    type t = index
  end

  let copy t =
    let copy_tree tree =
      { leaves= Compressed_public_key.Table.copy tree.leaves
      ; unset_slots= tree.unset_slots
      ; dirty= tree.dirty
      ; syncing= false
      ; nodes_height= tree.nodes_height
      ; nodes= List.map tree.nodes ~f:Dyn_array.copy
      ; dirty_indices= tree.dirty_indices }
    in
    {accounts= Dyn_array.copy t.accounts; tree= copy_tree t.tree}

  let empty_hash_at_heights depth =
    let empty_hash_at_heights = Array.create ~len:(depth + 1) empty_account_hash in
    let rec go i =
      if i <= depth then (
        let h = empty_hash_at_heights.(i - 1) in
        empty_hash_at_heights.(i) <- Hash.merge ~height:(i - 1) h h ;
        go (i + 1) )
    in
    go 1 ; empty_hash_at_heights

  let memoized_empty_hash_at_height = empty_hash_at_heights depth

  let empty_hash_at_height d = memoized_empty_hash_at_height.(d)

  (* if depth = N, leaves = 2^N *)
  let create () =
    { accounts= Dyn_array.create ()
    ; tree=
        { leaves= Compressed_public_key.Table.create ()
        ; unset_slots= Int.Set.empty
        ; dirty= false
        ; syncing= false
        ; nodes_height= 0
        ; nodes= []
        ; dirty_indices= [] } }

  let num_accounts t = Compressed_public_key.Table.length t.tree.leaves

  let _key_of_index t index =
    if index >= Dyn_array.length t.accounts then None
    else Some (Dyn_array.get t.accounts index |> Account.public_key)

  let location_of_key t key = Hashtbl.find t.tree.leaves key

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
    Hashtbl.remove t.tree.leaves old_key ;
    Hashtbl.set t.tree.leaves ~key:(Account.public_key account) ~data:index ;
    (t.tree).dirty_indices <- index :: t.tree.dirty_indices

  let allocate t key account =
    let merkle_index = Dyn_array.length t.accounts in
    Dyn_array.add t.accounts account ;
    Hashtbl.set t.tree.leaves ~key ~data:merkle_index ;
    (t.tree).dirty_indices <- merkle_index :: t.tree.dirty_indices ;
    merkle_index

  let get_or_create_account t key account =
    match location_of_key t key with
    | None ->
        let new_index = allocate t key account in
        let max_accounts = 1 lsl depth in
        if new_index > max_accounts then
          Result.Error Out_of_leaves
        else Result.Ok (`Added, new_index)
    | Some index -> Result.Ok (`Existed, index)

  let get_or_create_account_exn t key account =
    match get_or_create_account t key account with
    | Error e -> raise (Error_exception e)
    | Ok x -> x

  let set_at_index_exn t index account =
    if index < Dyn_array.length t.accounts then
      let old_account = Dyn_array.get t.accounts index in
      replace t index (Account.public_key old_account) account
    else failwith (index_not_found "set_at_index_exn" index)

  let set = set_at_index_exn

  let extend_tree t =
    let leaves = Dyn_array.length t.accounts in
    if leaves <> 0 then (
      let target_height = Int.max 1 (Int.ceil_log2 leaves) in
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
      Hash.of_account (Dyn_array.get t.accounts i)
    else empty_account_hash

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
      List.iter keys ~f:(fun k -> Compressed_public_key.Table.remove t.tree.leaves k) ;
      Dyn_array.delete_range t.accounts least len ;
      (* TODO: fixup hashes in a less terrible way *)
      (t.tree).dirty_indices <- List.init least ~f:(fun i -> i) ;
      (t.tree).nodes_height <- 0 ;
      (t.tree).nodes <- [] ;
      recompute_tree t )

  let merkle_root t : Root_hash.t =
    recompute_tree t ;
    if not (Int.Set.is_empty t.tree.unset_slots) then
      failwithf !"%{sexp:Int.Set.t} remain unset" t.tree.unset_slots () ;
    let height = t.tree.nodes_height in
    let base_root =
      match List.last t.tree.nodes with
      | None -> empty_account_hash
      | Some a -> Dyn_array.get a 0
    in
    let rec go i hash =
      if i = 0 then hash
      else
        let height = depth - i in
        let hash = Hash.merge ~height hash (empty_hash_at_height height) in
        go (i - 1) hash
    in
    Root_hash.of_hash (go (depth - height) base_root :> Snark_params.Tick.Pedersen.Digest.t)

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
              ((if is_left then (Path.Direction.Left, hash) else (Right, hash)) :: acc)
      in
      let leaf_hash_idx = index lxor 1 in
      let leaf_hash =
        if leaf_hash_idx >= Hashtbl.length t.tree.leaves then empty_account_hash
        else Hash.of_account (Dyn_array.get t.accounts leaf_hash_idx)
      in
      let is_left = index mod 2 = 0 in
      let non_root_nodes = List.take t.tree.nodes (depth - 1) in
      let base_path, base_path_height =
        go 1 (index lsr 1) non_root_nodes
          [(if is_left then (Left, leaf_hash) else (Right, leaf_hash))]
      in
      List.rev_append base_path
        (List.init (depth - base_path_height) ~f:(fun i ->
             (Path.Direction.Left, (empty_hash_at_height (i + base_path_height))) )) )

  let merkle_path = merkle_path_at_index_exn

  module For_tests = struct
    let get_leaf_hash_at_addr t addr = get_leaf_hash t (Address.to_int addr)
  end

  (* FIXME: Probably this will cause an error *)
  let merkle_path_at_addr_exn t a =
    assert (Address.depth a = depth - 1) ;
    merkle_path_at_index_exn t (Address.to_int a)

(* TODO: DELETE
  let set_at_addr_exn t addr acct =
    assert (Address.depth addr = depth - 1) ;
    set_at_index_exn t (Address.to_int addr) acct

*)
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
    let adepth = Address.depth a in
    assert (adepth < depth) ;
    let height = Address.height a in
    let index = Address.to_int a in
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
    let path_length = Address.depth a in
    assert (path_length < depth) ;
    (t.tree).dirty <- true ;
    let l = List.nth_exn t.tree.nodes (depth - path_length - 1) in
    let index = Address.to_int a in
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
    let height = depth - Address.depth a in
    let first_index = Address.to_int a lsl height in
    assert (List.length accounts <= 1 lsl height) ;
    make_space_for t (first_index + List.length accounts) ;
    List.iteri accounts ~f:(fun i a ->
        let new_index = first_index + i in
        if Int.Set.mem t.tree.unset_slots new_index then (
          replace t new_index Compressed_public_key.empty a ;
          (t.tree).unset_slots <- Int.Set.remove t.tree.unset_slots new_index )
        else set_at_index_exn t new_index a )

  let get_all_accounts_rooted_at_exn t a =
    let height = depth - Address.depth a in
    let first_index = Address.to_int a lsl height in
    let count = min (1 lsl height) (num_accounts t - first_index) in
    let subarr = Dyn_array.sub t.accounts first_index count in
    Dyn_array.to_list subarr
end
