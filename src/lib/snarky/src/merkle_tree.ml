open Core_kernel

module Address = struct
  type t = int
end

module Free_hash = struct
  type 'a t = Hash_value of 'a | Hash_empty | Compress of 'a t * 'a t
  [@@deriving sexp]

  let diff t1 t2 =
    let module M = struct
      exception Done of bool list
    end in
    let rec go path t1 t2 =
      match (t1, t2) with
      | Hash_empty, Hash_empty -> None
      | Hash_value x, Hash_value y ->
          if x = y then None else raise (M.Done path)
      | Compress (l1, r1), Compress (l2, r2) ->
          ignore (go (false :: path) l1 l2) ;
          ignore (go (true :: path) r1 r2) ;
          None
      | Hash_empty, Hash_value _
       |Hash_empty, Compress _
       |Hash_value _, Hash_empty
       |Hash_value _, Compress _
       |Compress _, Hash_empty
       |Compress _, Hash_value _ ->
          raise (M.Done path)
    in
    try go [] t1 t2 with M.Done addr -> Some addr

  let rec run t ~hash ~compress =
    match t with
    | Hash_value x -> hash (Some x)
    | Hash_empty -> hash None
    | Compress (l, r) ->
        compress (run ~hash ~compress l) (run ~hash ~compress r)
end

type ('hash, 'a) non_empty_tree =
  | Node of 'hash * ('hash, 'a) tree * ('hash, 'a) tree
  | Leaf of 'hash * 'a

and ('hash, 'a) tree = Non_empty of ('hash, 'a) non_empty_tree | Empty
[@@deriving sexp]

type ('hash, 'a) t =
  { tree: ('hash, 'a) non_empty_tree
  ; depth: int
  ; count: int
  ; hash: 'a option -> 'hash
  ; compress: 'hash -> 'hash -> 'hash }
[@@deriving sexp]

let check_exn {tree; depth; count; hash; compress} =
  let default = hash None in
  let rec check_hash = function
    | Non_empty t -> check_hash_non_empty t
    | Empty -> default
  and check_hash_non_empty = function
    | Leaf (h, x) ->
        assert (h = hash (Some x)) ;
        h
    | Node (h, l, r) ->
        assert (compress (check_hash l) (check_hash r) = h) ;
        h
  in
  ignore (check_hash_non_empty tree)

let non_empty_hash = function Node (h, _, _) -> h | Leaf (h, _) -> h

let depth {depth; _} = depth

let hash {tree; _} = non_empty_hash tree

let tree_hash ~default = function
  | Empty -> default
  | Non_empty t -> non_empty_hash t

let to_list : ('hash, 'a) t -> 'a list =
  let rec go acc = function
    | Empty -> acc
    | Non_empty (Leaf (_, x)) -> x :: acc
    | Non_empty (Node (h, l, r)) ->
        let acc' = go acc r in
        go acc' l
  in
  fun t -> go [] (Non_empty t.tree)

let left_tree hash compress depth x =
  let empty_hash = hash None in
  let rec go i h acc =
    if i = depth then (h, acc)
    else
      let h' = compress h empty_hash in
      go (i + 1) h' (Node (h', Non_empty acc, Empty))
  in
  let h = hash (Some x) in
  go 0 h (Leaf (h, x))

let insert hash compress t0 mask0 address x =
  let default = hash None in
  let rec go mask t =
    if mask = 0 then
      match t with
      | Empty -> Leaf (hash (Some x), x)
      | Non_empty _ -> failwith "Tree should be empty"
    else
      let go_left = mask land address = 0 in
      let mask' = mask lsr 1 in
      match t with
      | Empty ->
          if go_left then
            let t_l' = go mask' Empty in
            Node (compress (non_empty_hash t_l') default, Non_empty t_l', Empty)
          else
            let t_r' = go mask' Empty in
            Node (compress default (non_empty_hash t_r'), Empty, Non_empty t_r')
      | Non_empty (Node (h, t_l, t_r)) ->
          if go_left then
            let t_l' = go mask' t_l in
            Node
              ( compress (non_empty_hash t_l') (tree_hash ~default t_r)
              , Non_empty t_l'
              , t_r )
          else
            let t_r' = go mask' t_r in
            Node
              ( compress (tree_hash ~default t_l) (non_empty_hash t_r')
              , t_l
              , Non_empty t_r' )
      | Non_empty (Leaf _) -> failwith "Cannot insert into leaf"
  in
  go mask0 t0

let ith_bit n i = (n lsr i) land 1 = 1

let update ({hash; compress; tree= tree0; depth} as t) addr0 x =
  let tree_hash = tree_hash ~default:(hash None) in
  let rec go_non_empty tree i =
    match tree with
    | Leaf (_, _) -> Leaf (hash (Some x), x)
    | Node (_, t_l, t_r) ->
        let b = ith_bit addr0 i in
        let t_l', t_r' =
          if b then (t_l, go t_r (i - 1)) else (go t_l (i - 1), t_r)
        in
        Node (compress (tree_hash t_l') (tree_hash t_r'), t_l', t_r')
  and go tree i =
    match tree with
    | Non_empty tree -> Non_empty (go_non_empty tree i)
    | Empty -> failwith "Merkle_tree.update: Invalid address"
  in
  {t with tree= go_non_empty tree0 (depth - 1)}

let get {tree; depth; _} addr0 =
  let rec get t i =
    match t with Empty -> None | Non_empty t -> get_non_empty t i
  and get_non_empty t i =
    match t with
    | Node (_, l, r) ->
        let go_right = ith_bit addr0 i in
        if go_right then get r (i - 1) else get l (i - 1)
    | Leaf (_, x) -> Some x
  in
  get_non_empty tree (depth - 1)

let get_exn t addr = Option.value_exn (get t addr)

let set_dirty default tree addr x =
  let rec go tree addr =
    match (tree, addr) with
    | Empty, go_right :: bs ->
        let t = Non_empty (go Empty bs) in
        let l, r = if go_right then (Empty, t) else (t, Empty) in
        Node (default, l, r)
    | Empty, [] -> Leaf (default, x)
    | Non_empty t, _ -> go_non_empty t addr
  and go_non_empty tree addr =
    match (tree, addr) with
    | Leaf _, [] -> Leaf (default, x)
    | Node (_, l, r), go_right :: bs ->
        let l', r' =
          if go_right then (l, Non_empty (go r bs))
          else (Non_empty (go l bs), r)
        in
        Node (default, l', r')
    | Leaf _, _ :: _ | Node _, [] ->
        failwith "Merkle_tree.set_dirty (go_non_empty): Mismatch"
  in
  go_non_empty tree (List.rev addr)

let recompute_hashes {tree; depth; count; hash; compress} =
  let h =
    let default = hash None in
    fun t -> tree_hash ~default t
  in
  let rec go = function
    | Non_empty t -> Non_empty (go_non_empty t)
    | Empty -> Empty
  and go_non_empty = function
    | Leaf (_, x) -> Leaf (hash (Some x), x)
    | Node (_, l, r) ->
        let l' = go l in
        let r' = go r in
        Node (compress (h l') (h r'), l', r')
  in
  go_non_empty tree

let address_of_int ~depth n : bool list =
  List.init depth ~f:(fun i -> n land (1 lsl i) <> 0)

let add_many t xs =
  let default = t.hash None in
  let left_tree_dirty depth x =
    let rec go i acc =
      if i = depth then acc
      else go (i + 1) (Node (default, Non_empty acc, Empty))
    in
    go 0 (Leaf (default, x))
  in
  let add_one_dirty {tree; depth; count; hash; compress} x =
    if count = 1 lsl depth then
      let t_r = left_tree_dirty depth x in
      { tree= Node (default, Non_empty tree, Non_empty t_r)
      ; count= count + 1
      ; depth= depth + 1
      ; hash
      ; compress }
    else
      { tree= set_dirty default tree (address_of_int ~depth count) x
      ; count= count + 1
      ; depth
      ; hash
      ; compress }
  in
  let t = List.fold_left xs ~init:t ~f:add_one_dirty in
  {t with tree= recompute_hashes t}

let add {tree; depth; count; hash; compress} x =
  if count = 1 lsl depth then
    let h_r, t_r = left_tree hash compress depth x in
    let h_l = non_empty_hash tree in
    { tree= Node (compress h_l h_r, Non_empty tree, Non_empty t_r)
    ; count= count + 1
    ; depth= depth + 1
    ; hash
    ; compress }
  else
    { tree= insert hash compress (Non_empty tree) (1 lsl (depth - 1)) count x
    ; count= count + 1
    ; depth
    ; hash
    ; compress }

let root {tree; _} = non_empty_hash tree

let create ~hash ~compress x =
  {tree= Leaf (hash (Some x), x); count= 1; depth= 0; hash; compress}

let get_path {tree; hash; depth; _} addr0 =
  let default = hash None in
  let rec go acc t i =
    if i < 0 then acc
    else
      let go_right = ith_bit addr0 i in
      if go_right then
        match t with
        | Leaf _ -> failwith "get_path"
        | Node (_h, _t_l, Empty) -> failwith "get_path"
        | Node (_h, t_l, Non_empty t_r) ->
            go (tree_hash ~default t_l :: acc) t_r (i - 1)
      else
        match t with
        | Leaf _ -> failwith "get_path"
        | Node (_h, Empty, _t_r) -> failwith "get_path"
        | Node (_h, Non_empty t_l, t_r) ->
            go (tree_hash ~default t_r :: acc) t_l (i - 1)
  in
  go [] tree (depth - 1)

let implied_root ~compress addr0 entry_hash path0 =
  let rec go acc i path =
    match path with
    | [] -> acc
    | h :: hs ->
        go
          (if ith_bit addr0 i then compress h acc else compress acc h)
          (i + 1) hs
  in
  go entry_hash 0 path0

let rec free_tree_hash = function
  | Empty -> Free_hash.Hash_empty
  | Non_empty (Leaf (_, x)) -> Hash_value x
  | Non_empty (Node (_, l, r)) -> Compress (free_tree_hash l, free_tree_hash r)

let free_root {tree; _} = free_tree_hash (Non_empty tree)

let get_free_path {tree; depth; _} addr0 =
  let rec go acc t i =
    if i < 0 then acc
    else
      let go_right = ith_bit addr0 i in
      if go_right then
        match t with
        | Leaf _ -> failwith "get_path"
        | Node (_h, _t_l, Empty) -> failwith "get_path"
        | Node (_h, t_l, Non_empty t_r) ->
            go (free_tree_hash t_l :: acc) t_r (i - 1)
      else
        match t with
        | Leaf _ -> failwith "get_path"
        | Node (_h, Empty, _t_r) -> failwith "get_path"
        | Node (_h, Non_empty t_l, t_r) ->
            go (free_tree_hash t_r :: acc) t_l (i - 1)
  in
  go [] tree (depth - 1)

let implied_free_root addr0 x path0 =
  implied_root
    ~compress:(fun a b -> Free_hash.Compress (a, b))
    addr0 (Hash_value x) path0

type ('hash, 'a) merkle_tree = ('hash, 'a) t

module Checked
    (Impl : Snark_intf.S) (Hash : sig
        type var

        type value

        val typ : (var, value) Impl.Typ.t

        val hash : height:int -> var -> var -> (var, _) Impl.Checked.t

        val if_ :
          Impl.Boolean.var -> then_:var -> else_:var -> (var, _) Impl.Checked.t

        val assert_equal : var -> var -> (unit, _) Impl.Checked.t
    end) (Elt : sig
      type var

      type value

      val typ : (var, value) Impl.Typ.t

      val hash : var -> (Hash.var, _) Impl.Checked.t
    end) =
struct
  open Impl

  module Address = struct
    type var = Boolean.var list

    type value = int

    let typ ~depth : (var, value) Typ.t =
      Typ.transport
        (Typ.list ~length:depth Boolean.typ)
        ~there:(address_of_int ~depth)
        ~back:
          (List.foldi ~init:0 ~f:(fun i acc b ->
               if b then acc lor (1 lsl i) else acc ))
  end

  module Path = struct
    type value = Hash.value list

    type var = Hash.var list

    let typ ~depth : (var, value) Typ.t = Typ.(list ~length:depth Hash.typ)
  end

  let implied_root entry_hash addr0 path0 =
    let rec go height acc addr path =
      let open Let_syntax in
      match (addr, path) with
      | [], [] -> return acc
      | b :: bs, h :: hs ->
          let%bind l = Hash.if_ b ~then_:h ~else_:acc
          and r = Hash.if_ b ~then_:acc ~else_:h in
          let%bind acc' = Hash.hash ~height l r in
          go (height + 1) acc' bs hs
      | _, _ ->
          failwith
            "Merkle_tree.Checked.implied_root: address, path length mismatch"
    in
    go 0 entry_hash addr0 path0

  type _ Request.t +=
    | Get_element : Address.value -> (Elt.value * Path.value) Request.t
    | Get_path : Address.value -> Path.value Request.t
    | Set : Address.value * Elt.value -> unit Request.t

  (* addr0 should have least significant bit first *)
  let modify_req ~(depth : int) root addr0 ~f : (Hash.var, 's) Checked.t =
    let open Let_syntax in
    with_label "Merkle_tree.Checked.update_req"
      (let%bind prev, prev_path =
         request_witness
           Typ.(Elt.typ * Path.typ ~depth)
           As_prover.(
             map (read (Address.typ ~depth) addr0) ~f:(fun a -> Get_element a))
       in
       let%bind () =
         let%bind prev_entry_hash = Elt.hash prev in
         implied_root prev_entry_hash addr0 prev_path
         >>= Hash.assert_equal root
       in
       let%bind next = f prev in
       let%bind next_entry_hash = Elt.hash next in
       let%bind () =
         perform
           (let open As_prover in
           let open Let_syntax in
           let%map addr = read (Address.typ ~depth) addr0
           and next = read Elt.typ next in
           Set (addr, next))
       in
       implied_root next_entry_hash addr0 prev_path)

  (* addr0 should have least significant bit first *)
  let update_req ~(depth : int) ~root ~prev ~next addr0 :
      (Hash.var, _) Checked.t =
    let open Let_syntax in
    with_label "Merkle_tree.Checked.update_req"
      (let%bind prev_entry_hash = Elt.hash prev
       and next_entry_hash = Elt.hash next
       and prev_path =
         request_witness (Path.typ ~depth)
           As_prover.(
             map (read (Address.typ ~depth) addr0) ~f:(fun a -> Get_path a))
       in
       let%bind () =
         implied_root prev_entry_hash addr0 prev_path
         >>= Hash.assert_equal root
       in
       let%bind () =
         perform
           (let open As_prover in
           let open Let_syntax in
           let%map addr = read (Address.typ ~depth) addr0
           and next = read Elt.typ next in
           Set (addr, next))
       in
       implied_root next_entry_hash addr0 prev_path)

  (* addr0 should have least significant bit first *)
  let update ~(depth : int) ~root ~prev ~next addr0 :
      (Hash.var, (Hash.value, Elt.value) merkle_tree) Checked.t =
    let open Let_syntax in
    with_label "Merkle_tree.Checked.update"
      (let%bind prev_entry_hash = Elt.hash prev
       and next_entry_hash = Elt.hash next
       and prev_path =
         provide_witness (Path.typ ~depth)
           As_prover.(
             map2 ~f:get_path get_state (read (Address.typ ~depth) addr0))
       in
       let%bind prev_root_hash =
         implied_root prev_entry_hash addr0 prev_path
       in
       let%bind () = Hash.assert_equal root prev_root_hash
       and () =
         as_prover
           (let open As_prover in
           let open Let_syntax in
           let%bind addr = read (Address.typ ~depth) addr0
           and next = read Elt.typ next in
           modify_state (fun t -> update t addr next))
       in
       implied_root next_entry_hash addr0 prev_path)
end
