open Core_kernel

module Tree = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type ('hash, 'account) t =
        | Account of 'account
        | Hash of 'hash
        | Node of 'hash * ('hash, 'account) t * ('hash, 'account) t
      [@@deriving equal, sexp, yojson]

      let rec to_latest acct_to_latest = function
        | Account acct ->
            Account (acct_to_latest acct)
        | Hash hash ->
            Hash hash
        | Node (hash, l, r) ->
            Node (hash, to_latest acct_to_latest l, to_latest acct_to_latest r)
    end
  end]

  type ('hash, 'account) t = ('hash, 'account) Stable.Latest.t =
    | Account of 'account
    | Hash of 'hash
    | Node of 'hash * ('hash, 'account) t * ('hash, 'account) t
  [@@deriving equal, sexp, yojson]
end

module T = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type ('hash, 'key, 'account) t =
        { indexes : ('key * int) list
        ; depth : int
        ; tree : ('hash, 'account) Tree.Stable.V1.t
        }
      [@@deriving sexp, yojson]
    end
  end]

  type ('hash, 'key, 'account) t = ('hash, 'key, 'account) Stable.Latest.t =
    { indexes : ('key * int) list
    ; depth : int
    ; tree : ('hash, 'account) Tree.t
    }
  [@@deriving sexp, yojson]
end

module type S = sig
  type hash

  type account_id

  type account

  type t = (hash, account_id, account) T.t [@@deriving sexp, yojson]

  val of_hash : depth:int -> hash -> t

  val get_exn : t -> int -> account

  val path_exn : t -> int -> [ `Left of hash | `Right of hash ] list

  val set_exn : t -> int -> account -> t

  val find_index_exn : t -> account_id -> int

  val add_path :
    t -> [ `Left of hash | `Right of hash ] list -> account_id -> account -> t

  (** Same as [add_path], but using the hashes provided in the wide merkle path
      instead of recomputing them.
      This is unsafe: the hashes are not checked or recomputed.
  *)
  val add_wide_path_unsafe :
       t
    -> [ `Left of hash * hash | `Right of hash * hash ] list
    -> account_id
    -> account
    -> t

  val iteri : t -> f:(int -> account -> unit) -> unit

  val merkle_root : t -> hash

  val depth : t -> int
end

let tree { T.tree; _ } = tree

let of_hash ~depth h = { T.indexes = []; depth; tree = Hash h }

module Make (Hash : sig
  type t [@@deriving equal, sexp, yojson, compare]

  val merge : height:int -> t -> t -> t
end) (Account_id : sig
  type t [@@deriving equal, sexp, yojson]
end) (Account : sig
  type t [@@deriving equal, sexp, yojson]

  val data_hash : t -> Hash.t
end) : sig
  include
    S
      with type hash := Hash.t
       and type account_id := Account_id.t
       and type account := Account.t

  val hash : (Hash.t, Account.t) Tree.t -> Hash.t
end = struct
  type t = (Hash.t, Account_id.t, Account.t) T.t [@@deriving sexp, yojson]

  let of_hash ~depth (hash : Hash.t) = of_hash ~depth hash

  let hash : (Hash.t, Account.t) Tree.t -> Hash.t = function
    | Account a ->
        Account.data_hash a
    | Hash h ->
        h
    | Node (h, _, _) ->
        h

  type index = int [@@deriving sexp, yojson]

  let depth { T.depth; _ } = depth

  let merkle_root { T.tree; _ } = hash tree

  let add_path_impl ~replace_self tree0 path0 account =
    (* Takes height, left and right children and builds a pair of sibling nodes
       one level up *)
    let build_tail_f height (prev_l, prev_r) =
      replace_self ~f:(fun mself ->
          let self =
            match mself with
            | Some self ->
                self
            | None ->
                Hash.merge ~height (hash prev_l) (hash prev_r)
          in
          Tree.Node (self, prev_l, prev_r) )
    in
    (* Builds the tail of path, i.e. part of the path that is not present in
       the current ledger and we just add it all the way down to account
       using the path *)
    let build_tail hash_node_to_bottom_path =
      let bottom_el, bottom_to_hash_node_path =
        Mina_stdlib.Nonempty_list.(rev hash_node_to_bottom_path |> uncons)
      in
      (* Left and right branches of a node that is parent of the bottom node *)
      let init = replace_self ~f:(Fn.const (Tree.Account account)) bottom_el in
      List.foldi ~init bottom_to_hash_node_path ~f:build_tail_f
    in
    (* Traverses the tree along path, collecting nodes and untraversed sibling hashes
        Stops when encounters `Hash` or `Account` node.

       Returns the last visited node (`Hash` or `Account`), remainder of path and
       collected node/sibling hashes in bottom-to-top order.
    *)
    let rec traverse_through_nodes = function
      | Tree.Account _, _ :: _ ->
          failwith "path is longer than a tree's branch"
      | Account _, [] | Tree.Hash _, [] ->
          Tree.Account account
      | Tree.Hash h, fst_el :: rest ->
          let tail_l, tail_r =
            build_tail (Mina_stdlib.Nonempty_list.init fst_el rest)
          in
          Tree.Node (h, tail_l, tail_r)
      | Node (h, l, r), `Left _ :: rest ->
          Tree.Node (h, traverse_through_nodes (l, rest), r)
      | Node (h, l, r), `Right _ :: rest ->
          Tree.Node (h, l, traverse_through_nodes (r, rest))
      | Node _, [] ->
          failwith "path is shorter than a tree's branch"
    in
    traverse_through_nodes (tree0, List.rev path0)

  let add_path (t : t) path account_id account =
    let index =
      List.foldi path ~init:0 ~f:(fun i acc x ->
          match x with `Right _ -> acc + (1 lsl i) | `Left _ -> acc )
    in
    let replace_self ~f = function
      | `Left h_r ->
          (f None, Tree.Hash h_r)
      | `Right h_l ->
          (Tree.Hash h_l, f None)
    in
    { t with
      tree = add_path_impl ~replace_self t.tree path account
    ; indexes = (account_id, index) :: t.indexes
    }

  let add_wide_path_unsafe (t : t) path account_id account =
    let index =
      List.foldi path ~init:0 ~f:(fun i acc x ->
          match x with `Right _ -> acc + (1 lsl i) | `Left _ -> acc )
    in
    let replace_self ~f = function
      | `Left (h_l, h_r) ->
          (f (Some h_l), Tree.Hash h_r)
      | `Right (h_l, h_r) ->
          (Tree.Hash h_l, f (Some h_r))
    in
    { t with
      tree = add_path_impl ~replace_self t.tree path account
    ; indexes = (account_id, index) :: t.indexes
    }

  let iteri (t : t) ~f =
    let rec go acc i tree ~f =
      match tree with
      | Tree.Account a ->
          f acc a
      | Hash _ ->
          ()
      | Node (_, l, r) ->
          go acc (i - 1) l ~f ;
          go (acc + (1 lsl i)) (i - 1) r ~f
    in
    go 0 (t.depth - 1) t.tree ~f

  let ith_bit idx i = (idx lsr i) land 1 = 1

  let find_index_exn (t : t) aid =
    match List.Assoc.find t.indexes ~equal:Account_id.equal aid with
    | Some x ->
        x
    | None ->
        failwithf
          !"Sparse_ledger.find_index_exn: %{sexp:Account_id.t} not in %{sexp: \
            Account_id.t list}"
          aid
          (List.map t.indexes ~f:fst)
          ()

  let get_exn ({ T.tree; depth; _ } as t) idx =
    let rec go i tree =
      match (i < 0, tree) with
      | true, Tree.Account acct ->
          acct
      | false, Node (_, l, r) ->
          let go_right = ith_bit idx i in
          if go_right then go (i - 1) r else go (i - 1) l
      | _ ->
          let expected_kind = if i < 0 then "n account" else " node" in
          let kind =
            match tree with
            | Account _ ->
                "n account"
            | Hash _ ->
                " hash"
            | Node _ ->
                " node"
          in
          failwithf
            !"Sparse_ledger.get: Bad index %i. Expected a%s, but got a%s at \
              depth %i. Tree = %{sexp:t}, tree_depth = %d"
            idx expected_kind kind (depth - i) t depth ()
    in
    go (depth - 1) tree

  let set_exn (t : t) idx acct =
    let rec go i tree =
      match (i < 0, tree) with
      | true, Tree.Account _ ->
          Tree.Account acct
      | false, Node (_, l, r) ->
          let l, r =
            let go_right = ith_bit idx i in
            if go_right then (l, go (i - 1) r) else (go (i - 1) l, r)
          in
          Node (Hash.merge ~height:i (hash l) (hash r), l, r)
      | _ ->
          let expected_kind = if i < 0 then "n account" else " node" in
          let kind =
            match tree with
            | Account _ ->
                "n account"
            | Hash _ ->
                " hash"
            | Node _ ->
                " node"
          in
          failwithf
            "Sparse_ledger.set: Bad index %i. Expected a%s, but got a%s at \
             depth %i."
            idx expected_kind kind (t.depth - i) ()
    in
    { t with tree = go (t.depth - 1) t.tree }

  let path_exn { T.tree; depth; _ } idx =
    let rec go acc i tree =
      if i < 0 then acc
      else
        match tree with
        | Tree.Account _ ->
            failwithf "Sparse_ledger.path: Bad depth at index %i." idx ()
        | Hash _ ->
            failwithf "Sparse_ledger.path: Dead end at index %i." idx ()
        | Node (_, l, r) ->
            let go_right = ith_bit idx i in
            if go_right then go (`Right (hash l) :: acc) (i - 1) r
            else go (`Left (hash r) :: acc) (i - 1) l
    in
    go [] (depth - 1) tree
end

type ('hash, 'key, 'account) t = ('hash, 'key, 'account) T.t [@@deriving yojson]

let%test_module "sparse-ledger-test" =
  ( module struct
    module Hash = struct
      type t = Core_kernel.Md5.t [@@deriving sexp, compare]

      let equal h1 h2 = Int.equal (compare h1 h2) 0

      let to_yojson md5 = `String (Core_kernel.Md5.to_hex md5)

      let of_yojson = function
        | `String x ->
            Or_error.try_with (fun () -> Core_kernel.Md5.of_hex_exn x)
            |> Result.map_error ~f:Error.to_string_hum
        | _ ->
            Error "Expected a hex-encoded MD5 hash"

      let merge ~height x y =
        let open Md5 in
        digest_string
          (sprintf "sparse-ledger_%03d" height ^ to_binary x ^ to_binary y)

      let gen =
        Quickcheck.Generator.map String.quickcheck_generator
          ~f:Md5.digest_string
    end

    module Account = struct
      module T = struct
        type t =
          { name : Bounded_types.String.Stable.V1.t; favorite_number : int }
        [@@deriving bin_io, equal, sexp, yojson]
      end

      include T

      let key { name; _ } = name

      let data_hash t = Md5.digest_string (Binable.to_string (module T) t)

      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%map name = String.quickcheck_generator
        and favorite_number = Int.quickcheck_generator in
        { name; favorite_number }
    end

    module Account_id = struct
      type t = string [@@deriving sexp, equal, yojson]
    end

    include Make (Hash) (Account_id) (Account)

    let gen =
      let open Quickcheck.Generator in
      let open Let_syntax in
      let indexes max_depth t =
        let rec go addr d = function
          | Tree.Account a ->
              [ (Account.key a, addr) ]
          | Hash _ ->
              []
          | Node (_, l, r) ->
              go addr (d - 1) l @ go (addr lor (1 lsl d)) (d - 1) r
        in
        go 0 (max_depth - 1) t
      in
      let rec prune_hash_branches = function
        | Tree.Hash h ->
            Tree.Hash h
        | Account a ->
            Account a
        | Node (h, l, r) -> (
            match (prune_hash_branches l, prune_hash_branches r) with
            | Hash _, Hash _ ->
                Hash h
            | l, r ->
                Node (h, l, r) )
      in
      let rec gen depth =
        if depth = 0 then Account.gen >>| fun a -> Tree.Account a
        else
          let t =
            let sub = gen (depth - 1) in
            let%map l = sub and r = sub in
            Tree.Node (Hash.merge ~height:(depth - 1) (hash l) (hash r), l, r)
          in
          weighted_union
            [ (1. /. 3., Hash.gen >>| fun h -> Tree.Hash h); (2. /. 3., t) ]
      in
      let%bind depth = Int.gen_incl 0 16 in
      let%map tree = gen depth >>| prune_hash_branches in
      { T.tree; depth; indexes = indexes depth tree }

    let%test_unit "iteri consistent indices with t.indexes" =
      Quickcheck.test gen ~f:(fun t ->
          let indexes = Int.Set.of_list (t.indexes |> List.map ~f:snd) in
          iteri t ~f:(fun i _ ->
              [%test_result: bool]
                ~message:
                  "Iteri index should be contained in the indexes auxillary \
                   structure"
                ~expect:true (Int.Set.mem indexes i) ) )

    let%test_unit "path_test" =
      Quickcheck.test gen ~f:(fun t ->
          let root = { t with indexes = []; tree = Hash (merkle_root t) } in
          let t' =
            List.fold t.indexes ~init:root ~f:(fun acc (_, index) ->
                let account = get_exn t index in
                add_path acc (path_exn t index) (Account.key account) account )
          in
          assert (Tree.equal Hash.equal Account.equal t'.tree t.tree) )
  end )
