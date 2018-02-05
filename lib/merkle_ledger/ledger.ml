open Core;;

module type S =
  functor (Hash : sig 
       val hash_account : 'account -> 'hash 
       val hash_unit : unit -> 'hash
       val merge : 'hash -> 'hash -> 'hash
     end) -> sig

  type 'account entry = 
    { merkle_index : int
    ; account : 'account }

  type ('key, 'account) accounts = ('key, 'account entry) Hashtbl.t

  type 'key leafs = 'key array

  type 'hash nodes = 'hash array list

  type ('key, 'hash) tree = 
    { mutable leafs : 'key leafs
    ; mutable nodes : 'hash nodes
    ; mutable dirty_indices : int list }

  type ('hash, 'key, 'account) t = 
    { accounts : ('key, 'account) accounts
    ; tree : ('key, 'hash) tree
    }

  type 'hash path_elem = 
    | Left of 'hash
    | Right of 'hash

  type 'hash path = 'hash path_elem list

  val get
    : ('hash, 'key, 'account) t
    -> 'key
    -> 'account option

  val update
    : ('hash, 'key, 'account) t
    -> 'key
    -> 'account
    -> unit

  val merkle_root
    : ('hash, 'key, 'account) t
    -> 'hash

  val merkle_path
    : ('hash, 'key, 'account) t
    -> 'key
    -> 'hash path option
end

module Make 
    (Hash : sig 
       val hash_account : 'account -> 'hash 
       val hash_unit : unit -> 'hash
       val merge : 'hash -> 'hash -> 'hash
     end) = struct

  type 'account entry = 
    { merkle_index : int
    ; account : 'account }

  type ('key, 'account) accounts = ('key, 'account entry) Hashtbl.t

  type 'key leafs = 'key array

  type 'hash nodes = 'hash array list

  type ('key, 'hash) tree = 
    { mutable leafs : 'key leafs
    ; mutable nodes : 'hash nodes
    ; mutable dirty_indices : int list }

  type ('hash, 'key, 'account) t = 
    { accounts : ('key, 'account) accounts
    ; tree : ('key, 'hash) tree 
    }

  type 'hash path_elem = 
    | Left of 'hash
    | Right of 'hash

  type 'hash path = 'hash path_elem list

  let get t key = 
    Option.map
      (Hashtbl.find t.accounts key)
      (fun entry -> entry.account)
  ;;

  let update t key account = 
    match Hashtbl.find t.accounts key with
    | None -> 
      let _hash = Hash.hash_account account in
      let merkle_index = Array.length t.tree.leafs in
      Hashtbl.set t.accounts ~key ~data:{ merkle_index = merkle_index; account };
      t.tree.leafs <- Array.append t.tree.leafs [| key |];
      t.tree.dirty_indices <- List.append t.tree.dirty_indices [ merkle_index ];
    | Some entry -> 
      Hashtbl.set t.accounts ~key ~data:{ merkle_index = entry.merkle_index; account };
      t.tree.dirty_indices <- List.append t.tree.dirty_indices [ entry.merkle_index ];
  ;;

  let extend_tree tree = 
    let leafs = Array.length tree.leafs in
    let tgt_node_sets = Int.ceil_log2 leafs in
    let cur_node_sets = List.length tree.nodes in
    let new_node_sets = tgt_node_sets - cur_node_sets in
    tree.nodes <- List.concat [ tree.nodes; (List.init new_node_sets ~f:(fun _ -> [||])) ];
    let target_lengths = 
      List.rev
        (List.init
          (List.length tree.nodes)
          ~f:(fun i -> Int.pow 2 i))
    in
    tree.nodes <-
      List.map2_exn
        tree.nodes
        target_lengths
        ~f:(fun nodes length -> 
          let new_elems = length - (Array.length nodes) in
          Array.concat [ nodes; Array.init new_elems ~f:(fun x -> Hash.hash_unit ()) ])

  let rec recompute_layer prev_layer_hashes layers dirty_indices =
    let updates = List.zip_exn prev_layer_hashes dirty_indices in
    let head = List.nth_exn layers 0 in
    let tail = List.drop layers 1 in
    List.iter
      updates
      ~f:(fun ((left, right), idx) -> Array.set head idx (Hash.merge left right));
    let next_layer_dirty_indices = 
      Int.Set.to_list (Int.Set.of_list (List.map dirty_indices ~f:(fun x -> x / 2)))
    in
    let get_head_hash i = 
      if i < Array.length head
      then Array.get head i
      else Hash.hash_unit ()
    in
    let next_layer_prev_layer_hashes = 
      List.zip_exn
        (List.map next_layer_dirty_indices ~f:(fun i -> get_head_hash (2 * i)))
        (List.map next_layer_dirty_indices ~f:(fun i -> get_head_hash (2 * i + 1)))
    in
    if List.length tail > 0
    then recompute_layer next_layer_prev_layer_hashes tail next_layer_dirty_indices
    else ()

  let recompute_tree t =
    extend_tree t.tree;
    let layer_dirty_indices = 
      Int.Set.to_list (Int.Set.of_list (List.map t.tree.dirty_indices ~f:(fun x -> x / 2)))
    in
    let get_leaf_hash i = 
      if i < Array.length t.tree.leafs
      then Hash.hash_account (Hashtbl.find_exn t.accounts (Array.get t.tree.leafs i))
      else Hash.hash_unit ()
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
    match List.last t.tree.nodes with
    | None -> Hash.hash_unit ()
    | Some a -> Array.get a 0
  ;;

  let merkle_path t key = 
    recompute_tree t;
    Option.map
      (Hashtbl.find t.accounts key)
      (fun entry -> 
         let merkle_index = entry.merkle_index in
         let indices = 
           List.init 
             ((List.length t.tree.nodes) + 1)
             ~f:(fun i -> merkle_index/(Int.pow 2 i))
         in
         let directions = 
           List.map 
             (List.take indices ((List.length indices) - 1))
             ~f:(fun i -> if i % 2 = 0 then `Left else `Right)
         in
         let hashes = 
           List.map2_exn
             (List.drop indices 1)
             t.tree.nodes
             ~f:(fun i nodes -> Array.get nodes i)
         in
         List.map2_exn 
           directions
           hashes
           ~f:(fun dir hash -> 
             match dir with
             | `Left -> Left hash
             | `Right -> Right hash)
      )
  ;;

end

let%test "trivial" = false
;;
