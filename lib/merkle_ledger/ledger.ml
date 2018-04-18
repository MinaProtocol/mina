open Core;;

(* SOMEDAY: handle empty wallets *)

module type S = sig
  type hash
  type account
  type key

  val depth : int

  type index = int

  type t
  [@@deriving sexp, bin_io]

  val copy : t -> t

  module Path : sig
    type elem =
      [ `Left of hash
      | `Right of hash
      ]
    [@@deriving sexp]

    val elem_hash : elem -> hash

    type t = elem list
    [@@deriving sexp]

    val implied_root : t -> hash -> hash
  end

  val create : unit -> t

  val length : t -> int

  val get : t -> key -> account option

  val update : t -> key -> account -> unit

  val merkle_root : t -> hash

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value
  val hash_fold_t : Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state
  val compare : t -> t -> int

  val merkle_path
    : t -> key -> Path.t option

  val key_of_index
    : t -> index -> key option

  val index_of_key
    : t -> key -> index option

  val key_of_index_exn
    : t -> index -> key

  val index_of_key_exn
    : t -> key -> index

  val get_at_index
    : t -> index -> [ `Ok of account | `Index_not_found ]

  val update_at_index
    : t -> index -> account -> [ `Ok | `Index_not_found ]

  val merkle_path_at_index
    : t -> index -> [ `Ok of Path.t | `Index_not_found ]

  val get_at_index_exn
    : t -> index -> account

  val update_at_index_exn
    : t -> index -> account -> unit

  val merkle_path_at_index_exn
    : t -> index -> Path.t
end

module type F =
  functor (Hash : sig 
       type hash [@@deriving sexp, hash, compare, bin_io]
       type account [@@deriving sexp, bin_io]
       val hash_account : account -> hash 
       val empty_hash : hash
       val merge : hash -> hash -> hash
     end)
    (Key : sig 
        type t [@@deriving sexp, bin_io]
        include Hashable.S_binable with type t := t
     end)
    (Depth : sig val depth : int end)
    -> S with type hash := Hash.hash
          and type account := Hash.account
          and type key := Key.t

module Make 
    (Hash : sig 
       type hash [@@deriving sexp, hash, compare, bin_io]
       type account [@@deriving sexp, bin_io]
       val hash_account : account -> hash 
       val empty_hash : hash
       val merge : hash -> hash -> hash
     end)
    (Key : sig 
        type t [@@deriving sexp, bin_io]
        include Hashable.S_binable with type t := t
     end)
    (Depth : sig val depth : int end)
    : S with type hash := Hash.hash
         and type account := Hash.account
         and type key := Key.t
= struct
  include Depth

  type entry = 
    { merkle_index : int
    ; account : Hash.account 
    }
  [@@deriving sexp, bin_io]

  type accounts = entry Key.Table.t [@@deriving sexp, bin_io]

  module DynArray = struct
    include DynArray
    let sexp_of_t sexp_of_a t = [%sexp_of: a list] (DynArray.to_list t)
    let t_of_sexp a_of_sexp ls = DynArray.of_list ([%of_sexp: a list] ls)
    include Binable.Of_binable1(Array)(struct
        type 'a t = 'a DynArray.t
        let to_binable = DynArray.to_array
        let of_binable = DynArray.of_array
      end)
  end

  type index = int

  type leafs = Key.t DynArray.t [@@deriving sexp, bin_io]

  type nodes = Hash.hash DynArray.t list [@@deriving sexp, bin_io]

  type tree = 
    { leafs : leafs
    ; mutable nodes_height : int
    ; mutable nodes : nodes
    ; mutable dirty_indices : int list }
  [@@deriving sexp, bin_io]

  type t = 
    { accounts : accounts
    ; tree : tree
    }
  [@@deriving sexp, bin_io]

  let copy t =
    let copy_tree tree =
      { leafs = DynArray.copy tree.leafs
      ; nodes_height = tree.nodes_height
      ; nodes = tree.nodes
      ; dirty_indices = tree.dirty_indices
      }
    in
    { accounts = Key.Table.copy t.accounts
    ; tree = copy_tree t.tree
    }

  module Path = struct
    type elem = 
      [ `Left of Hash.hash
      | `Right of Hash.hash
      ]
    [@@deriving sexp]

    let elem_hash = function
      | `Left h | `Right h -> h

    type t = elem list [@@deriving sexp]

    let implied_root (t : t) hash =
      List.fold t ~init:hash ~f:(fun acc elem ->
        match elem with
        | `Left h -> Hash.merge acc h
        | `Right h -> Hash.merge h acc)
  end

  let create_account_table () = Key.Table.create ()
  ;;

  let empty_hash_at_heights depth =
    let empty_hash_at_heights = Array.create (depth + 1) Hash.empty_hash in
    let rec go i =
      if i <= depth
      then begin
        let h = empty_hash_at_heights.(i - 1) in
        empty_hash_at_heights.(i) <- Hash.merge h h;
        go (i + 1)
      end
    in
    go 1;
    empty_hash_at_heights
  ;;

  let memoized_empty_hash_at_height = empty_hash_at_heights depth

  let empty_hash_at_height d = 
    memoized_empty_hash_at_height.(d)

  (* if depth = N, leafs = 2^N *)
  let create () =
    { accounts = create_account_table ()
    ; tree = { leafs = DynArray.create ()
             ; nodes_height = 0
             ; nodes = []
             ; dirty_indices = [] 
             }
    }
  ;;

  let length t = Key.Table.length t.accounts

  let key_of_index t index =
    if index >= DynArray.length t.tree.leafs
    then None
    else Some (DynArray.get t.tree.leafs index)

  let index_of_key t key =
    Option.map (Hashtbl.find t.accounts key)
      ~f:(fun { merkle_index; _ } -> merkle_index)

  let key_of_index_exn t index = Option.value_exn (key_of_index t index)
  let index_of_key_exn t key = Option.value_exn (index_of_key t key)

  let get t key = 
    Option.map
      (Hashtbl.find t.accounts key)
      ~f:(fun entry -> entry.account)
  ;;

  let index_not_found label index =
    failwithf "Ledger.%s: Index %d not found"
      label index ()

  let get_at_index t index =
    if index >= DynArray.length t.tree.leafs
    then `Index_not_found
    else
      let key = DynArray.get t.tree.leafs index in
      `Ok (Hashtbl.find_exn t.accounts key).account

  let get_at_index_exn t index =
    match get_at_index t index with
    | `Ok account -> account
    | `Index_not_found ->
      index_not_found "get_at_index_exn" index

  let update t key account = 
    match Hashtbl.find t.accounts key with
    | None -> 
      let merkle_index = DynArray.length t.tree.leafs in
      Hashtbl.set t.accounts ~key ~data:{ merkle_index; account };
      DynArray.add t.tree.leafs key;
      t.tree.dirty_indices <- merkle_index :: t.tree.dirty_indices;
    | Some entry -> 
      Hashtbl.set t.accounts ~key ~data:{ merkle_index = entry.merkle_index; account };
      t.tree.dirty_indices <- entry.merkle_index :: t.tree.dirty_indices;
  ;;

  let update_at_index t index account =
    let leafs = t.tree.leafs in
    if index < DynArray.length leafs
    then begin
      let key = DynArray.get leafs index in
      Hashtbl.set t.accounts ~key
        ~data:{ merkle_index = index; account };
      t.tree.dirty_indices <- index :: t.tree.dirty_indices;
      `Ok
    end else `Index_not_found

  let update_at_index_exn t index account =
    match update_at_index t index account with
    | `Ok -> ()
    | `Index_not_found ->
      index_not_found "update_at_index_exn" index

  let extend_tree tree = 
    let leafs = DynArray.length tree.leafs in
    if leafs <> 0 then begin
      let target_depth = Int.max 1 (Int.ceil_log2 leafs) in
      let current_depth = tree.nodes_height in
      let additional_depth = target_depth - current_depth in
      tree.nodes_height <- tree.nodes_height + additional_depth;
      tree.nodes <- List.concat [ tree.nodes; (List.init additional_depth ~f:(fun _ -> DynArray.create ())) ];
      List.iteri
        tree.nodes
        ~f:(fun i nodes -> 
          let length = Int.pow 2 (tree.nodes_height - 1 - i) in
          let new_elems = length - (DynArray.length nodes) in
          DynArray.append (DynArray.init new_elems (fun x -> Hash.empty_hash)) nodes;
        )
    end
  ;;

  let rec recompute_layers curr_height get_prev_hash layers dirty_indices =
    match layers with
    | [] -> ()
    | curr :: layers ->
      let get_curr_hash =
        let n = DynArray.length curr in
        fun i ->
          if i < n
          then DynArray.get curr i
          else empty_hash_at_height curr_height
      in
      List.iter dirty_indices ~f:(fun i ->
        DynArray.set curr i
          (Hash.merge
             (get_prev_hash (2 * i))
             (get_prev_hash (2 * i + 1))));
      let dirty_indices =
        List.dedup_and_sort ~compare:Int.compare
          (List.map dirty_indices ~f:(fun x -> x lsr 1))
      in
      recompute_layers
        (curr_height + 1)
        get_curr_hash
        layers
        dirty_indices

  let recompute_tree t =
    if not (List.is_empty t.tree.dirty_indices) then begin
      extend_tree t.tree;
      let layer_dirty_indices = 
        Int.Set.to_list (Int.Set.of_list (List.map t.tree.dirty_indices ~f:(fun x -> x / 2)))
      in
      let get_leaf_hash i = 
        if i < DynArray.length t.tree.leafs
        then Hash.hash_account (Hashtbl.find_exn t.accounts (DynArray.get t.tree.leafs i)).account
        else Hash.empty_hash
      in
      recompute_layers 
        1 get_leaf_hash t.tree.nodes layer_dirty_indices;
      t.tree.dirty_indices <- []
    end
  ;;

  let merkle_root t = 
    recompute_tree t;
    let height = t.tree.nodes_height in
    let base_root =
      match List.last t.tree.nodes with
      | None -> Hash.empty_hash
      | Some a -> DynArray.get a 0
    in
    let rec go i hash =
      if i = 0
      then hash
      else 
        let hash = Hash.merge hash (empty_hash_at_height (depth - i)) in
        go (i-1) hash
    in
    go (depth - height) base_root
  ;;

  let hash t = Hash.hash_hash (merkle_root t)
  let hash_fold_t state t = Ppx_hash_lib.Std.Hash.fold_int state (hash t)
  let compare t t' = Hash.compare_hash (merkle_root t) (merkle_root t')

  let merkle_path t key = 
    recompute_tree t;
    Option.map (Hashtbl.find t.accounts key) ~f:(fun entry ->
      let addr0 = entry.merkle_index in
      let rec go height addr layers acc =
        match layers with
        | [] -> acc, height
        | curr :: layers ->
          let is_left = addr mod 2 = 0 in
          let hash =
            let sibling = addr lxor 1 in
            if sibling < DynArray.length curr
            then DynArray.get curr sibling
            else empty_hash_at_height height
          in
          go (height + 1) (addr lsr 1) layers
            ((if is_left then `Left hash else `Right hash) :: acc)
      in
      let leaf_hash_idx = addr0 lxor 1 in
      let leaf_hash = 
        if leaf_hash_idx >= DynArray.length t.tree.leafs
        then Hash.empty_hash
        else (Hash.hash_account (Hashtbl.find_exn t.accounts (DynArray.get t.tree.leafs leaf_hash_idx)).account)  
      in
      let is_left = addr0 mod 2 = 0 in
      let non_root_nodes =
        List.take t.tree.nodes (depth - 1)
      in
      let base_path, base_path_height = 
        go 1 (addr0 lsr 1) non_root_nodes
          [ if is_left then `Left leaf_hash else `Right leaf_hash ]
      in
      List.rev_append 
        base_path
        (List.init 
          (depth - base_path_height) 
          ~f:(fun i -> `Left (empty_hash_at_height (i + base_path_height))))
    )
  ;;

  let merkle_path_at_index t index =
    match Option.(key_of_index t index >>= merkle_path t) with
    | None -> `Index_not_found
    | Some path -> `Ok path

  let merkle_path_at_index_exn t index =
    match merkle_path_at_index t index with
    | `Ok path -> path
    | `Index_not_found ->
      index_not_found "merkle_path_at_index_exn" index
end
