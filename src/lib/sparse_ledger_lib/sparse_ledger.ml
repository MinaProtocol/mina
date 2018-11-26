open Core_kernel

type ('hash, 'account) tree =
  | Account of 'account
  | Hash of 'hash
  | Node of 'hash * ('hash, 'account) tree * ('hash, 'account) tree
[@@deriving bin_io, eq, sexp]

type index = int [@@deriving bin_io, sexp]

type ('hash, 'key, 'account) t =
  { indexes: ('key, index) List.Assoc.t
  ; depth: int
  ; tree: ('hash, 'account) tree }
[@@deriving bin_io, sexp]

let tree {tree; _} = tree

module type S = sig
  type hash

  type key

  type account

  type nonrec t = (hash, key, account) t [@@deriving bin_io, sexp]

  val of_hash : depth:int -> hash -> t

  val get_exn : t -> index -> account

  val path_exn : t -> index -> [`Left of hash | `Right of hash] list

  val set_exn : t -> index -> account -> t

  val find_index_exn : t -> key -> index

  val add_path :
    t -> [`Left of hash | `Right of hash] list -> key -> account -> t

  val merkle_root : t -> hash
end

let of_hash ~depth h = {indexes= []; depth; tree= Hash h}

module Make (Hash : sig
  type t [@@deriving bin_io, eq, sexp]

  val merge : height:int -> t -> t -> t
end) (Key : sig
  type t [@@deriving bin_io, eq, sexp]
end) (Account : sig
  type t [@@deriving bin_io, eq, sexp]

  val hash : t -> Hash.t
end) =
struct
  type tree_tmp = (Hash.t, Account.t) tree [@@deriving eq]

  type tree = tree_tmp [@@deriving eq]

  type t_tmp = (Hash.t, Key.t, Account.t) t [@@deriving bin_io, sexp]

  type t = t_tmp [@@deriving bin_io, sexp]

  let of_hash = of_hash

  let hash = function
    | Account a -> Account.hash a
    | Hash h -> h
    | Node (h, _, _) -> h

  type index = int [@@deriving bin_io, sexp]

  let merkle_root {tree; _} = hash tree

  let add_path depth0 tree0 path0 account =
    let rec build_tree height p =
      match p with
      | `Left h_r :: path ->
          let l = build_tree (height - 1) path in
          Node (Hash.merge ~height (hash l) h_r, l, Hash h_r)
      | `Right h_l :: path ->
          let r = build_tree (height - 1) path in
          Node (Hash.merge ~height h_l (hash r), Hash h_l, r)
      | [] ->
          assert (height = -1) ;
          Account account
    in
    let rec union height tree path =
      match (tree, path) with
      | Hash h, path ->
          let t = build_tree height path in
          assert (Hash.equal h (hash t)) ;
          t
      | Node (h, l, r), `Left h_r :: path ->
          assert (Hash.equal h_r (hash r)) ;
          let l = union (height - 1) l path in
          Node (h, l, r)
      | Node (h, l, r), `Right h_l :: path ->
          assert (Hash.equal h_l (hash l)) ;
          let r = union (height - 1) r path in
          Node (h, l, r)
      | Node _, [] -> failwith "Path too short"
      | Account _, _ :: _ -> failwith "Path too long"
      | Account a, [] ->
          assert (Account.equal a account) ;
          tree
    in
    union (depth0 - 1) tree0 (List.rev path0)

  let add_path t path key account =
    let index =
      List.foldi path ~init:0 ~f:(fun i acc x ->
          match x with `Right _ -> acc + (1 lsl i) | `Left _ -> acc )
    in
    { t with
      tree= add_path t.depth t.tree path account
    ; indexes= (key, index) :: t.indexes }

  let ith_bit idx i = (idx lsr i) land 1 = 1

  let find_index_exn t pk = List.Assoc.find_exn t.indexes ~equal:Key.equal pk

  let get_exn {tree; depth; _} idx =
    let rec go i tree =
      match (i < 0, tree) with
      | true, Account acct -> acct
      | false, Node (_, l, r) ->
          let go_right = ith_bit idx i in
          if go_right then go (i - 1) r else go (i - 1) l
      | _ -> failwith "Sparse_ledger.get: Bad index"
    in
    go (depth - 1) tree

  let set_exn t idx acct =
    let rec go i tree =
      match (i < 0, tree) with
      | true, Account _ -> Account acct
      | false, Node (_, l, r) ->
          let l, r =
            let go_right = ith_bit idx i in
            if go_right then (l, go (i - 1) r) else (go (i - 1) l, r)
          in
          Node (Hash.merge ~height:i (hash l) (hash r), l, r)
      | _ -> failwith "Sparse_ledger.get: Bad index"
    in
    {t with tree= go (t.depth - 1) t.tree}

  let path_exn {tree; depth; _} idx =
    let rec go acc i tree =
      if i < 0 then acc
      else
        match tree with
        | Account _ -> failwith "Sparse_ledger.path: Bad depth"
        | Hash _ -> failwith "Sparse_ledger.path: Dead end"
        | Node (_, l, r) ->
            let go_right = ith_bit idx i in
            if go_right then go (`Right (hash l) :: acc) (i - 1) r
            else go (`Left (hash r) :: acc) (i - 1) l
    in
    go [] (depth - 1) tree
end

let%test_module "sparse-ledger-test" =
  ( module struct
    module Hash = struct
      include Md5

      let merge ~height x y =
        let open Md5 in
        digest_string
          (sprintf "sparse-ledger_%03d" height ^ to_binary x ^ to_binary y)

      let gen = Quickcheck.Generator.map String.gen ~f:digest_string
    end

    module Account = struct
      module T = struct
        type t = {name: string; favorite_number: int}
        [@@deriving bin_io, eq, sexp]
      end

      include T

      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%map name = String.gen and favorite_number = Int.gen in
        {name; favorite_number}

      let key {name; _} = name

      let hash t = Md5.digest_string (Binable.to_string (module T) t)
    end

    include Make (Hash) (String) (Account)

    let gen =
      let open Quickcheck.Generator in
      let open Let_syntax in
      let indexes max_depth t =
        let rec go addr d = function
          | Account a -> [(Account.key a, addr)]
          | Hash _ -> []
          | Node (_, l, r) ->
              go addr (d - 1) l @ go (addr lor (1 lsl d)) (d - 1) r
        in
        go 0 (max_depth - 1) t
      in
      let rec prune_hash_branches = function
        | Hash h -> Hash h
        | Account a -> Account a
        | Node (h, l, r) -> (
          match (prune_hash_branches l, prune_hash_branches r) with
          | Hash _, Hash _ -> Hash h
          | l, r -> Node (h, l, r) )
      in
      let rec gen depth =
        if depth = 0 then Account.gen >>| fun a -> Account a
        else
          let t =
            let sub = gen (depth - 1) in
            let%map l = sub and r = sub in
            Node (Hash.merge ~height:(depth - 1) (hash l) (hash r), l, r)
          in
          weighted_union
            [(1. /. 3., Hash.gen >>| fun h -> Hash h); (2. /. 3., t)]
      in
      let%bind depth = Int.gen_incl 0 16 in
      let%map tree = gen depth >>| prune_hash_branches in
      {tree; depth; indexes= indexes depth tree}

    let%test_unit "path_test" =
      Quickcheck.test gen ~f:(fun t ->
          let root = {t with indexes= []; tree= Hash (merkle_root t)} in
          let t' =
            List.fold t.indexes ~init:root ~f:(fun acc (_, index) ->
                let account = get_exn t index in
                add_path acc (path_exn t index) (Account.key account) account
            )
          in
          assert (equal_tree t'.tree t.tree) )
  end )
