open Core

module Make
    (Hash : sig
       type t [@@deriving bin_io, eq]

       val merge : t -> t -> t
     end)
    (Key : sig type t [@@deriving bin_io, eq] end)
    (Account : sig
       type t [@@deriving bin_io, eq]

       val key : t -> Key.t
       val hash : t -> Hash.t
     end) = struct
  type tree =
    | Account of Account.t
    | Hash of Hash.t
    | Node of Hash.t * tree * tree
  [@@deriving bin_io]

  let hash = function
    | Account a -> Account.hash a
    | Hash h -> h
    | Node (h, _, _) -> h

  type index = int [@@deriving bin_io]

  type t =
    { indexes : (Key.t, index) List.Assoc.t
    ; depth   : int
    ; tree    : tree
    }
  [@@deriving bin_io]

  let of_hash ~depth h =
    { indexes = []; depth; tree = Hash h }

  let merkle_root { tree; _ } = hash tree

  let is_prefix ~depth ~prefix idx = failwith "TODO"

  let add_path tree0 path0 account =
    let rec build_tree = function
      | `Left h_r :: path ->
        let l = build_tree path in
        Node (Hash.merge (hash l) h_r, l, Hash h_r)
      | `Right h_l :: path ->
        let r = build_tree path in
        Node (Hash.merge h_l (hash r), Hash h_l, r)
      | [] ->
        Account account
    in
    let rec union tree path =
      match tree, path with
      | Hash h, path ->
        let t = build_tree path in
        assert (Hash.equal h (hash t));
        t
      | Node (h, l, r), (`Left h_r :: path) ->
        assert (Hash.equal h_r (hash r));
        let l = union l path in
        Node (h, l, r)
      | Node (h, l, r), (`Right h_l :: path) ->
        assert (Hash.equal h_l (hash l));
        let r = union r path in
        Node (h, l, r)
      | Node _, [] -> failwith "Path too short"
      | Account _, _::_ -> failwith "Path too long"
      | Account a, [] ->
        assert (Account.equal a account);
        tree
    in
    union tree0 (List.rev path0)
  ;;

  let add_path t path account =
    let index =
      List.foldi path ~init:0 ~f:(fun i acc x ->
        match x with
        | `Right _ -> acc + (1 lsl i)
        | `Left _ -> acc)
    in
    { t with tree = add_path t.tree path account 
    ; indexes = (Account.key account, index) :: t.indexes
    }

  let ith_bit idx i = (idx lsr i) land 1 = 1

  let find_index_exn t pk =
    List.Assoc.find_exn t.indexes ~equal:Key.equal pk

  let get_exn { tree; depth; _ } idx =
    let rec go i tree =
      match i < 0, tree with
      | true, Account acct -> acct
      | false, Node (_, l, r) ->
        let go_right = ith_bit idx i in
        if go_right then go (i - 1) r else go (i - 1) l
      | _ -> failwith "Sparse_ledger.get: Bad index"
    in
    go (depth - 1) tree

  let set_exn t idx acct =
    let rec go i tree =
      match i < 0, tree with
      | true, Account _ -> Account acct
      | false, Node (_, l, r) ->
        let l, r =
          let go_right = ith_bit idx i in
          if go_right
          then (l, go (i - 1) r)
          else (go (i - 1) l, r)
        in
        Node (Hash.merge (hash l) (hash r), l, r)
      | _ -> failwith "Sparse_ledger.get: Bad index"
    in
    { t with tree = go (t.depth - 1) t.tree }

  let path_exn { tree; depth; _ } idx =
    let rec go acc i tree =
      if i < 0
      then acc
      else
        match tree with
        | Account _ -> failwith "Sparse_ledger.path: Bad depth"
        | Hash _ -> failwith "Sparse_ledger.path: Dead end"
        | Node (_, l, r) ->
          let go_right = ith_bit idx i in
          if go_right
          then go (hash l :: acc) (i - 1) r
          else go (hash r :: acc) (i - 1) l
    in
    go [] (depth - 1) tree
end

