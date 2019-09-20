open Core_kernel

module Poly = struct
  module Tree = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type ('hash, 'account) t =
            | Account of 'account
            | Hash of 'hash
            | Node of 'hash * ('hash, 'account) t * ('hash, 'account) t
          [@@deriving bin_io, version, eq, sexp, to_yojson, version]
        end

        include T
      end

      module Latest = V1
    end

    type ('hash, 'account) t = ('hash, 'account) Stable.Latest.t =
      | Account of 'account
      | Hash of 'hash
      | Node of 'hash * ('hash, 'account) t * ('hash, 'account) t
    [@@deriving eq, sexp, to_yojson]
  end

  module Stable = struct
    module V1 = struct
      module T = struct
        type ('hash, 'key, 'account) t =
          { indexes: ('key * int) list
          ; depth: int
          ; tree: ('hash, 'account) Tree.Stable.V1.t }
        [@@deriving bin_io, sexp, to_yojson, version]
      end

      include T
    end

    module Latest = V1
  end

  type ('hash, 'key, 'account) t = ('hash, 'key, 'account) Stable.Latest.t =
    { indexes: ('key * int) list
    ; depth: int
    ; tree: ('hash, 'account) Tree.Stable.V1.t }
  [@@deriving sexp, to_yojson]
end

module type S = sig
  type hash

  type key

  type account

  module Stable : sig
    module V1 : sig
      type t = (hash, key, account) Poly.Stable.V1.t
      [@@deriving bin_io, sexp, to_yojson, version]
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp, to_yojson]

  val of_hash : depth:int -> hash -> t

  val get_exn : t -> int -> account

  val path_exn : t -> int -> [`Left of hash | `Right of hash] list

  val set_exn : t -> int -> account -> t

  val find_index_exn : t -> key -> int

  val add_path :
    t -> [`Left of hash | `Right of hash] list -> key -> account -> t

  val iteri : t -> f:(int -> account -> unit) -> unit

  val merkle_root : t -> hash
end

let tree {Poly.tree; _} = tree

let of_hash ~depth h = {Poly.indexes= []; depth; tree= Hash h}

module Make (Hash : sig
  type t [@@deriving bin_io, eq, sexp, to_yojson, compare, version]

  val merge : height:int -> t -> t -> t
end) (Key : sig
  type t [@@deriving bin_io, eq, sexp, to_yojson, version]
end) (Account : sig
  type t [@@deriving bin_io, eq, sexp, to_yojson, version]

  val data_hash : t -> Hash.t
end) : sig
  include
    S
    with type hash := Hash.t
     and type key := Key.t
     and type account := Account.t

  val hash : (Hash.t, Account.t) Poly.Tree.t -> Hash.t
end = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = (Hash.t, Key.t, Account.t) Poly.Stable.V1.t
        [@@deriving bin_io, sexp, to_yojson, version {unnumbered}]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp, to_yojson]

  let of_hash ~depth (hash : Hash.t) = of_hash ~depth hash

  let hash : (Hash.t, Account.t) Poly.Tree.t -> Hash.t = function
    | Account a ->
        Account.data_hash a
    | Hash h ->
        h
    | Node (h, _, _) ->
        h

  type index = int [@@deriving bin_io, sexp, to_yojson]

  let merkle_root {Poly.tree; _} = hash tree

  let add_path depth0 tree0 path0 account =
    (* let open Poly.Tree.V1 in *)
    let rec build_tree height p =
      match p with
      | `Left h_r :: path ->
          let l = build_tree (height - 1) path in
          Poly.Tree.Node (Hash.merge ~height (hash l) h_r, l, Hash h_r)
      | `Right h_l :: path ->
          let r = build_tree (height - 1) path in
          Node (Hash.merge ~height h_l (hash r), Hash h_l, r)
      | [] ->
          assert (height = -1) ;
          Account account
    in
    let rec union height tree path =
      match (tree, path) with
      | Poly.Tree.Hash h, path ->
          let t = build_tree height path in
          [%test_result: Hash.t]
            ~message:
              "Hashes in union are not equal, something is wrong with your \
               ledger"
            ~expect:h (hash t) ;
          t
      | Node (h, l, r), `Left h_r :: path ->
          assert (Hash.equal h_r (hash r)) ;
          let l = union (height - 1) l path in
          Node (h, l, r)
      | Node (h, l, r), `Right h_l :: path ->
          assert (Hash.equal h_l (hash l)) ;
          let r = union (height - 1) r path in
          Node (h, l, r)
      | Node _, [] ->
          failwith "Path too short"
      | Account _, _ :: _ ->
          failwith "Path too long"
      | Account a, [] ->
          assert (Account.equal a account) ;
          tree
    in
    union (depth0 - 1) tree0 (List.rev path0)

  let add_path (t : t) path key account =
    let index =
      List.foldi path ~init:0 ~f:(fun i acc x ->
          match x with `Right _ -> acc + (1 lsl i) | `Left _ -> acc )
    in
    { t with
      tree= add_path t.depth t.tree path account
    ; indexes= (key, index) :: t.indexes }

  let iteri (t : t) ~f =
    let rec go acc i tree ~f =
      match tree with
      | Poly.Tree.Account a ->
          f acc a
      | Hash _ ->
          ()
      | Node (_, l, r) ->
          go acc (i - 1) l ~f ;
          go (acc + (1 lsl i)) (i - 1) r ~f
    in
    go 0 (t.depth - 1) t.tree ~f

  let ith_bit idx i = (idx lsr i) land 1 = 1

  let find_index_exn (t : t) pk =
    List.Assoc.find_exn t.indexes ~equal:Key.equal pk

  let get_exn {Poly.tree; depth; _} idx =
    let rec go i tree =
      match (i < 0, tree) with
      | true, Poly.Tree.Account acct ->
          acct
      | false, Node (_, l, r) ->
          let go_right = ith_bit idx i in
          if go_right then go (i - 1) r else go (i - 1) l
      | _ ->
          failwith "Sparse_ledger.get: Bad index"
    in
    go (depth - 1) tree

  let set_exn (t : t) idx acct =
    let rec go i tree =
      match (i < 0, tree) with
      | true, Poly.Tree.Account _ ->
          Poly.Tree.Account acct
      | false, Node (_, l, r) ->
          let l, r =
            let go_right = ith_bit idx i in
            if go_right then (l, go (i - 1) r) else (go (i - 1) l, r)
          in
          Node (Hash.merge ~height:i (hash l) (hash r), l, r)
      | _ ->
          failwith "Sparse_ledger.set: Bad index"
    in
    {t with tree= go (t.depth - 1) t.tree}

  let path_exn {Poly.tree; depth; _} idx =
    let rec go acc i tree =
      if i < 0 then acc
      else
        match tree with
        | Poly.Tree.Account _ ->
            failwith "Sparse_ledger.path: Bad depth"
        | Hash _ ->
            failwith "Sparse_ledger.path: Dead end"
        | Node (_, l, r) ->
            let go_right = ith_bit idx i in
            if go_right then go (`Right (hash l) :: acc) (i - 1) r
            else go (`Left (hash r) :: acc) (i - 1) l
    in
    go [] (depth - 1) tree
end

type ('hash, 'key, 'account) t = ('hash, 'key, 'account) Poly.t
[@@deriving to_yojson]

let%test_module "sparse-ledger-test" =
  ( module struct
    module Hash = struct
      module Stable = struct
        module V1 = struct
          module T = struct
            type t = Core_kernel.Md5.Stable.V1.t
            [@@deriving bin_io, sexp, version {unnumbered}]

            let to_yojson md5 = `String (Core_kernel.Md5.to_hex md5)

            [%%define_locally
            Md5.(equal)]

            let compare a b = String.compare (Md5.to_hex a) (Md5.to_hex b)

            let merge ~height x y =
              let open Md5 in
              digest_string
                ( sprintf "sparse-ledger_%03d" height
                ^ to_binary x ^ to_binary y )
          end

          include T
        end

        module Latest = V1
      end

      type t = Stable.Latest.t [@@deriving eq, sexp, to_yojson, compare]

      let merge = Stable.Latest.merge

      let gen =
        Quickcheck.Generator.map String.quickcheck_generator
          ~f:Md5.digest_string
    end

    module Account = struct
      module Stable = struct
        module V1 = struct
          module T = struct
            type t = {name: string; favorite_number: int}
            [@@deriving bin_io, eq, sexp, to_yojson, version {unnumbered}]
          end

          include T

          let gen =
            let open Quickcheck.Generator.Let_syntax in
            let%map name = String.quickcheck_generator
            and favorite_number = Int.quickcheck_generator in
            {name; favorite_number}

          let key {name; _} = name

          let data_hash t = Md5.digest_string (Binable.to_string (module T) t)
        end

        module Latest = V1
      end

      type t = Stable.Latest.t = {name: string; favorite_number: int}
      [@@deriving sexp, to_yojson, eq]

      [%%define_locally
      Stable.Latest.(key, gen)]
    end

    module Key = struct
      module Stable = struct
        module V1 = struct
          module T = struct
            type t = string
            [@@deriving bin_io, eq, sexp, to_yojson, version {unnumbered}]
          end

          include T
        end

        module Latest = V1
      end

      type t = Stable.Latest.t [@@deriving sexp, to_yojson]
    end

    include Make (Hash.Stable.Latest) (Key.Stable.Latest)
              (Account.Stable.Latest)

    let gen =
      let open Quickcheck.Generator in
      let open Let_syntax in
      let indexes max_depth t =
        let rec go addr d = function
          | Poly.Tree.Account a ->
              [(Account.key a, addr)]
          | Hash _ ->
              []
          | Node (_, l, r) ->
              go addr (d - 1) l @ go (addr lor (1 lsl d)) (d - 1) r
        in
        go 0 (max_depth - 1) t
      in
      let rec prune_hash_branches = function
        | Poly.Tree.Hash h ->
            Poly.Tree.Hash h
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
        if depth = 0 then Account.gen >>| fun a -> Poly.Tree.Account a
        else
          let t =
            let sub = gen (depth - 1) in
            let%map l = sub and r = sub in
            Poly.Tree.Node
              (Hash.merge ~height:(depth - 1) (hash l) (hash r), l, r)
          in
          weighted_union
            [(1. /. 3., Hash.gen >>| fun h -> Poly.Tree.Hash h); (2. /. 3., t)]
      in
      let%bind depth = Int.gen_incl 0 16 in
      let%map tree = gen depth >>| prune_hash_branches in
      {Poly.tree; depth; indexes= indexes depth tree}

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
          let root = {t with indexes= []; tree= Hash (merkle_root t)} in
          let t' =
            List.fold t.indexes ~init:root ~f:(fun acc (_, index) ->
                let account = get_exn t index in
                add_path acc (path_exn t index) (Account.key account) account
            )
          in
          assert (Poly.Tree.equal Hash.equal Account.equal t'.tree t.tree) )
  end )
