open Core;;

(* SOMEDAY: handle empty wallets *)

module type S =
  functor (Hash : sig 
       type hash [@@deriving sexp]
       type account [@@deriving sexp]
       val hash_account : account -> hash 
       val hash_unit : hash
       val merge : hash -> hash -> hash
     end)
    (Key : sig 
        type t [@@deriving sexp]
        include Hashable.S with type t := t
     end) -> sig

  type entry = 
    { merkle_index : int
    ; account : Hash.account }

  type key = Key.t

  type accounts = (key, entry) Hashtbl.t

  module DynArray : sig
    type 'a t
  end

  type leafs = key DynArray.t [@@deriving sexp]

  type nodes = Hash.hash DynArray.t list [@@deriving sexp]

  type tree = 
    { leafs : leafs
    ; mutable nodes : nodes
    ; mutable dirty_indices : int list }
  [@@deriving sexp]

  type t = 
    { accounts : accounts
    ; tree : tree 
    ; depth : int
    }
  [@@deriving sexp]

  type path_elem = 
    | Left of Hash.hash
    | Right of Hash.hash

  type path = path_elem list [@@deriving sexp]

  val create : int -> t

  val length : t -> int

  val get
    : t
    -> key
    -> Hash.account option

  val update
    : t
    -> key
    -> Hash.account
    -> unit

  val merkle_root
    : t
    -> Hash.hash

  val merkle_path
    : t
    -> key
    -> path option
end

module Make 
    (Hash : sig 
       type hash [@@deriving sexp]
       type account [@@deriving sexp]
       val hash_account : account -> hash 
       val hash_unit : hash
       val merge : hash -> hash -> hash
     end)
    (Key : sig 
        type t [@@deriving sexp]
        include Hashable.S with type t := t
     end) = struct

  type key = Key.t [@@deriving sexp]

  type entry = 
    { merkle_index : int
    ; account : Hash.account 
    }
  [@@deriving sexp]

  type accounts = entry Key.Table.t [@@deriving sexp]

  module DynArray = struct
    include DynArray
    let sexp_of_t sexp_of_a t = [%sexp_of: a list] (DynArray.to_list t)
    let t_of_sexp a_of_sexp ls = DynArray.of_list ([%of_sexp: a list] ls)
  end

  type leafs = key DynArray.t [@@deriving sexp]

  type nodes = Hash.hash DynArray.t list [@@deriving sexp]

  type tree = 
    { leafs : leafs
    ; mutable nodes : nodes
    ; mutable dirty_indices : int list }
  [@@deriving sexp]

  type t = 
    { accounts : accounts
    ; tree : tree 
    ; depth : int
    }
  [@@deriving sexp]

  type path_elem = 
    | Left of Hash.hash
    | Right of Hash.hash
  [@@deriving sexp]

  type path = path_elem list [@@deriving sexp]

  let create_account_table () = Key.Table.create ()
  ;;

  (* if depth = N, leafs = 2^N *)
  let create depth = 
    { accounts = create_account_table ()
    ; tree = { leafs = DynArray.create ()
             ; nodes = []
             ; dirty_indices = [] 
             } 
    ; depth
    }
  ;;

  let length t = Key.Table.length t.accounts

  let get t key = 
    Option.map
      (Hashtbl.find t.accounts key)
      ~f:(fun entry -> entry.account)
  ;;

  let update t key account = 
    match Hashtbl.find t.accounts key with
    | None -> 
      let merkle_index = DynArray.length t.tree.leafs in
      Hashtbl.set t.accounts ~key ~data:{ merkle_index; account };
      DynArray.add t.tree.leafs key;
      t.tree.dirty_indices <-  merkle_index :: t.tree.dirty_indices;
    | Some entry -> 
      Hashtbl.set t.accounts ~key ~data:{ merkle_index = entry.merkle_index; account };
      t.tree.dirty_indices <- entry.merkle_index :: t.tree.dirty_indices;
  ;;

  let extend_tree tree = 
    let leafs = DynArray.length tree.leafs in
    if leafs <> 0 then begin
      let target_depth = Int.max 1 (Int.ceil_log2 leafs) in
      let current_depth = List.length tree.nodes in
      let additional_depth = target_depth - current_depth in
      tree.nodes <- List.concat [ tree.nodes; (List.init additional_depth ~f:(fun _ -> DynArray.create ())) ];
      let target_lengths = 
        let n = List.length tree.nodes in
        List.init n ~f:(fun i -> Int.pow 2 (n - 1 - i))
      in
      List.iter2_exn
        tree.nodes
        target_lengths
        ~f:(fun nodes length -> 
          let new_elems = length - (DynArray.length nodes) in
          DynArray.append (DynArray.init new_elems (fun x -> Hash.hash_unit)) nodes;
        )
    end
  ;;

  let rec recompute_layer prev_layer_hashes layers dirty_indices =
    let updates = List.zip_exn prev_layer_hashes dirty_indices in
    if List.length layers = 0 then ()
    else 
      match layers with
      | [] -> failwith "Merkle_tree: Empty layers"
      | head :: tail -> 
        List.iter
          updates
          ~f:(fun ((left, right), idx) -> DynArray.set head idx (Hash.merge left right));
        let next_layer_dirty_indices = 
          List.dedup_and_sort
            (List.map dirty_indices ~f:(fun x -> x  lsr 1))
            ~compare:Int.compare
        in
        let get_head_hash i = 
          if i < DynArray.length head
          then DynArray.get head i 
          else Hash.hash_unit
        in
        let next_layer_prev_layer_hashes = 
          List.zip_exn
            (List.map next_layer_dirty_indices ~f:(fun i -> get_head_hash (2 * i)))
            (List.map next_layer_dirty_indices ~f:(fun i -> get_head_hash (2 * i + 1)))
        in
        match tail with 
        | _ :: _ -> recompute_layer next_layer_prev_layer_hashes tail next_layer_dirty_indices
        | [] -> ()
  ;;

  let recompute_tree t =
    extend_tree t.tree;
    let layer_dirty_indices = 
      Int.Set.to_list (Int.Set.of_list (List.map t.tree.dirty_indices ~f:(fun x -> x / 2)))
    in
    let get_leaf_hash i = 
      if i < DynArray.length t.tree.leafs
      then Hash.hash_account (Hashtbl.find_exn t.accounts (DynArray.get t.tree.leafs i)).account
      else Hash.hash_unit
    in
    let prev_layer_hashes =
      List.zip_exn
        (List.map layer_dirty_indices ~f:(fun i -> get_leaf_hash (2 * i)))
        (List.map layer_dirty_indices ~f:(fun i -> get_leaf_hash (2 * i + 1)))
    in
    recompute_layer 
      prev_layer_hashes t.tree.nodes layer_dirty_indices;
    t.tree.dirty_indices <- []
  ;;


  let merkle_root t = 
    recompute_tree t;
    let depth = List.length t.tree.nodes in
    let base_root =
      match List.last t.tree.nodes with
      | None -> Hash.hash_unit
      | Some a -> DynArray.get a 0
    in
    let rec go i hash =
      let hash = Hash.merge hash Hash.hash_unit in
      if i = 0
      then hash
      else go (i-1) hash
    in
    go (t.depth - depth - 1) base_root
  ;;

  let merkle_path t key = 
    recompute_tree t;
    let base_path = 
      Option.map
        (Hashtbl.find t.accounts key)
        (fun entry -> 
           let merkle_index = entry.merkle_index in
           let indices = 
             List.init 
               ((List.length t.tree.nodes) + 1)
               ~f:(fun i -> merkle_index/(Int.pow 2 i))
           in
           let parent_indices = List.drop indices 1 in
           let drop_last ls = List.take ls (List.length ls - 1) in
           let directions = 
             List.map 
               (drop_last indices)
               ~f:(fun i -> if i % 2 = 0 then `Left else `Right)
           in
           let tail_hashes = 
             List.map2_exn
               (drop_last parent_indices)
               (drop_last t.tree.nodes)
               ~f:(fun i nodes -> 
                 let idx = 
                   if i % 2 = 0
                   then i + 1
                   else i - 1
                 in
                 DynArray.get nodes idx)
           in
           let leaf_hash_idx = 
             if merkle_index % 2 = 0
             then merkle_index + 1
             else merkle_index - 1
           in
           let leaf_hash = 
             if leaf_hash_idx < DynArray.length t.tree.leafs
             then Hash.hash_account (Hashtbl.find_exn t.accounts (DynArray.get t.tree.leafs leaf_hash_idx)).account
             else (Hash.hash_unit)
           in
           let hashes = leaf_hash::tail_hashes in
           List.map2_exn 
             directions
             hashes
             ~f:(fun dir hash -> 
               match dir with
               | `Left -> Left hash
               | `Right -> Right hash)
        )
    in 
    Option.map 
      base_path
      (fun base_path -> 
         let base_path_depth = List.length base_path in
         base_path @ (List.init (t.depth - base_path_depth) ~f:(fun _ -> Left Hash.hash_unit))
      )
  ;;
end
