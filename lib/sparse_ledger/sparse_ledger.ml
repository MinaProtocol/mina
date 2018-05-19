open Core

module Make
    (Hash : sig
       type t [@@deriving bin_io, eq, sexp]

       val merge : height:int -> t -> t -> t
     end)
    (Key : sig type t [@@deriving bin_io, eq, sexp] end)
    (Account : sig
       type t [@@deriving bin_io, eq, sexp]

       val key : t -> Key.t
       val hash : t -> Hash.t
     end) = struct
  type tree =
    | Account of Account.t
    | Hash of Hash.t
    | Node of Hash.t * tree * tree
  [@@deriving bin_io, eq, sexp]

  let hash = function
    | Account a -> Account.hash a
    | Hash h -> h
    | Node (h, _, _) -> h

  type index = int [@@deriving bin_io, sexp]

  type t =
    { indexes : (Key.t, index) List.Assoc.t
    ; depth   : int
    ; tree    : tree
    }
  [@@deriving bin_io, sexp]

  let of_hash ~depth h =
    { indexes = []; depth; tree = Hash h }

  let merkle_root { tree; _ } = hash tree

  (* TODO: Potential off-by-one here *)
  let add_path depth tree0 path0 account =
    let rec build_tree height = function
      | `Left h_r :: path ->
        let l = build_tree (height - 1) path in
        Node (Hash.merge ~height (hash l) h_r, l, Hash h_r)
      | `Right h_l :: path ->
        let r = build_tree (height - 1) path in
        Node (Hash.merge ~height h_l (hash r), Hash h_l, r)
      | [] ->
        Account account
    in
    let rec union height tree path =
      match tree, path with
      | Hash h, path ->
        let t = build_tree height path in
        assert (Hash.equal h (hash t));
        t
      | Node (h, l, r), (`Left h_r :: path) ->
        assert (Hash.equal h_r (hash r));
        let l = union height l path in
        Node (h, l, r)
      | Node (h, l, r), (`Right h_l :: path) ->
        assert (Hash.equal h_l (hash l));
        let r = union height r path in
        Node (h, l, r)
      | Node _, [] -> failwith "Path too short"
      | Account _, _::_ -> failwith "Path too long"
      | Account a, [] ->
        assert (Account.equal a account);
        tree
    in
    union (depth - 1) tree0 (List.rev path0)
  ;;

  let add_path t path account =
    let index =
      List.foldi path ~init:0 ~f:(fun i acc x ->
        match x with
        | `Right _ -> acc + (1 lsl i)
        | `Left _ -> acc)
    in
    { t with tree = add_path t.depth t.tree path account 
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
        Node (Hash.merge ~height:i (hash l) (hash r), l, r)
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
          then go (`Right (hash l) :: acc) (i - 1) r
          else go (`Left (hash r) :: acc) (i - 1) l
    in
    go [] (depth - 1) tree
end

let%test_module "sparse-ledger-test" =
  (module struct
    module Hash = struct
      include Md5
      let merge ~height x y =
        Md5.(digest_string (sprintf "sparse-ledger_%03d" height ^ to_binary x ^ to_binary y))

      let gen = Quickcheck.Generator.map String.gen ~f:digest_string
    end

    module Account = struct
      module T = struct
        type t =
          { name : string
          ; favorite_number : int
          }
        [@@deriving bin_io, eq, sexp]
      end
      include T

      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%map name = String.gen and favorite_number = Int.gen in
        { name; favorite_number }

      let key { name } = name

      let hash t = Md5.digest_string (Binable.to_string (module T) t)
    end

    include Make(Hash)(String)(Account)

    let gen =
      let rec tree_depth = function
        | Account _ | Hash _ -> 0
        | Node (_, l, r) -> 1 + max (tree_depth l) (tree_depth r)
      in
      let rec prune_hash_branches = function
        | Hash h -> Hash h
        | Account a -> Account a
        | Node (h, l, r) ->
          begin match prune_hash_branches l, prune_hash_branches r with 
          | Hash _, Hash _ -> Hash h
          | l, r -> Node (h, l, r)
          end
      in
      let prune_shallow_accounts max_depth t =
        let rec go d t =
          match t with
          | Account a ->
            if d < max_depth then Hash (Account.hash a) else t
          | Hash _ -> t
          | Node (h, l, r) ->
            Node (h, go (d + 1) l, go (d + 1) r)
        in
        go 0 t
      in
      let indexes max_depth t =
        let rec go addr d = function
          | Account a -> [ (Account.key a, addr) ]
          | Hash _ -> []
          | Node (_, l, r) ->
            go addr (d - 1) l
            @ go (addr lor (1 lsl d)) (d - 1) r
        in
        go 0 (max_depth - 1) t
      in
      let rec fix_hashes height t =
        match t with
        | Account _ ->
          assert (height = 0);
          t
        | Hash _ -> t
        | Node (_, l, r) ->
          let height = height - 1 in
          let l = fix_hashes height l in
          let r = fix_hashes height r in
          Node (Hash.merge ~height (hash l) (hash r), l, r)
      in
      let open Quickcheck.Generator in
      recursive (fun gen_tree ->
        variant3 Account.gen Hash.gen (tuple2 gen_tree gen_tree) >>| function
        | `A account -> Account account
        | `B hash -> Hash hash
        | `C (l, r) -> Node (Hash.merge ~height:0 (hash l) (hash r), l, r))
      >>| fun tree ->
      let depth = tree_depth tree in
      let tree = prune_shallow_accounts depth tree |> prune_hash_branches |> fix_hashes depth in
      { tree; depth; indexes = indexes depth tree }

    let%test_unit "path_test" =
      Quickcheck.test gen ~f:(fun t ->
        let root = { t with indexes = []; tree = Hash (merkle_root t) } in
        let t' =
          List.fold t.indexes ~init:root ~f:(fun acc (_, index) ->
            let account = get_exn t index in
            add_path acc (path_exn t index) account)
        in
        assert (equal_tree t'.tree t.tree))

  end)
