open Core_kernel

let empty = Outside_hash_image.t

module Tree = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('account_update, 'account_update_digest, 'digest) t =
            ( 'account_update
            , 'account_update_digest
            , 'digest )
            Mina_wire_types.Mina_base.Zkapp_command.Call_forest.Tree.V1.t =
        { account_update : 'account_update
        ; account_update_digest : 'account_update_digest
        ; calls :
            ( ('account_update, 'account_update_digest, 'digest) t
            , 'digest )
            With_stack_hash.Stable.V1.t
            list
        }
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  let rec fold_forest (ts : (_ t, _) With_stack_hash.t list) ~f ~init =
    List.fold ts ~init ~f:(fun acc { elt; stack_hash = _ } ->
        fold elt ~init:acc ~f )

  and fold { account_update; calls; account_update_digest = _ } ~f ~init =
    fold_forest calls ~f ~init:(f init account_update)

  let rec fold_forest2_exn (ts1 : (_ t, _) With_stack_hash.t list)
      (ts2 : (_ t, _) With_stack_hash.t list) ~f ~init =
    List.fold2_exn ts1 ts2 ~init
      ~f:(fun acc { elt = elt1; stack_hash = _ } { elt = elt2; stack_hash = _ }
         -> fold2_exn elt1 elt2 ~init:acc ~f )

  and fold2_exn
      { account_update = account_update1
      ; calls = calls1
      ; account_update_digest = _
      }
      { account_update = account_update2
      ; calls = calls2
      ; account_update_digest = _
      } ~f ~init =
    fold_forest2_exn calls1 calls2 ~f
      ~init:(f init account_update1 account_update2)

  let iter_forest2_exn ts1 ts2 ~f =
    fold_forest2_exn ts1 ts2 ~init:() ~f:(fun () p1 p2 -> f p1 p2)

  let iter2_exn ts1 ts2 ~f =
    fold2_exn ts1 ts2 ~init:() ~f:(fun () p1 p2 -> f p1 p2)

  let rec mapi_with_trees' ~i (t : _ t) ~f =
    let account_update = f i t.account_update t in
    let l, calls = mapi_forest_with_trees' ~i:(i + 1) t.calls ~f in
    ( l
    , { calls; account_update; account_update_digest = t.account_update_digest }
    )

  and mapi_forest_with_trees' ~i x ~f =
    let rec go i acc = function
      | [] ->
          (i, List.rev acc)
      | t :: ts ->
          let l, elt' = mapi_with_trees' ~i ~f (With_stack_hash.elt t) in
          go l (With_stack_hash.map t ~f:(fun _ -> elt') :: acc) ts
    in
    go i [] x

  let mapi_with_trees t ~f = mapi_with_trees' ~i:0 t ~f |> snd

  let mapi_forest_with_trees t ~f = mapi_forest_with_trees' ~i:0 t ~f |> snd

  let mapi' ~i t ~f =
    mapi_with_trees' ~i t ~f:(fun i account_update _ -> f i account_update)

  let mapi_forest' ~i t ~f =
    mapi_forest_with_trees' ~i t ~f:(fun i account_update _ ->
        f i account_update )

  let rec deferred_mapi_with_trees' ~i (t : _ t) ~f =
    let open Async_kernel.Deferred.Let_syntax in
    let%bind l, calls =
      deferred_mapi_forest_with_trees' ~i:(i + 1) t.calls ~f
    in
    let%map account_update = f i t.account_update t in
    ( l
    , { calls; account_update; account_update_digest = t.account_update_digest }
    )

  and deferred_mapi_forest_with_trees' ~i x ~f =
    let open Async_kernel.Deferred.Let_syntax in
    let rec go i acc = function
      | [] ->
          return (i, List.rev acc)
      | t :: ts ->
          let%bind l, elt' =
            deferred_mapi_with_trees' ~i ~f (With_stack_hash.elt t)
          in
          go l (With_stack_hash.map t ~f:(fun _ -> elt') :: acc) ts
    in
    go i [] x

  let map_forest ~f t = mapi_forest' ~i:0 ~f:(fun _ x -> f x) t |> snd

  let mapi_forest ~f t = mapi_forest' ~i:0 ~f t |> snd

  let deferred_map_forest ~f t =
    let open Async_kernel.Deferred in
    deferred_mapi_forest_with_trees' ~i:0 ~f:(fun _ x -> f x) t >>| snd

  let deferred_mapi_forest ~f t =
    let open Async_kernel.Deferred in
    deferred_mapi_forest_with_trees' ~i:0 ~f t >>| snd

  let hash { account_update = _; calls; account_update_digest } =
    let stack_hash = match calls with [] -> empty | e :: _ -> e.stack_hash in
    Random_oracle.hash ~init:Hash_prefix_states.account_update_node
      [| account_update_digest; stack_hash |]
end

type ('a, 'b, 'c) tree = ('a, 'b, 'c) Tree.t

module type Digest_intf = sig
  module Account_update : sig
    include Digest_intf.S

    module Checked : sig
      include Digest_intf.S_checked

      val create : ?chain:Mina_signature_kind.t -> Account_update.Checked.t -> t

      val create_body :
        ?chain:Mina_signature_kind.t -> Account_update.Body.Checked.t -> t
    end

    include Digest_intf.S_aux with type t := t and type checked := Checked.t

    val create : ?chain:Mina_signature_kind.t -> Account_update.t -> t

    val create_body : ?chain:Mina_signature_kind.t -> Account_update.Body.t -> t
  end

  module rec Forest : sig
    include Digest_intf.S

    module Checked : sig
      include Digest_intf.S_checked

      val empty : t

      val cons : Tree.Checked.t -> t -> t
    end

    include Digest_intf.S_aux with type t := t and type checked := Checked.t

    val empty : t

    val cons : Tree.t -> Forest.t -> Forest.t
  end

  and Tree : sig
    include Digest_intf.S

    module Checked : sig
      include Digest_intf.S_checked

      val create :
           account_update:Account_update.Checked.t
        -> calls:Forest.Checked.t
        -> Tree.Checked.t
    end

    include Digest_intf.S_aux with type t := t and type checked := Checked.t

    val create : (_, Account_update.t, Forest.t) tree -> Tree.t
  end
end

module Make_digest_sig
    (T : Mina_wire_types.Mina_base.Zkapp_command.Digest_types.S) =
struct
  module type S =
    Digest_intf
      with type Account_update.Stable.V1.t = T.Account_update.V1.t
       and type Forest.Stable.V1.t = T.Forest.V1.t
end

module Make_digest_types = struct
  module Account_update = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Kimchi_backend.Pasta.Basic.Fp.Stable.V1.t
        [@@deriving sexp, compare, equal, hash, yojson]

        let to_latest = Fn.id
      end
    end]
  end

  module Forest = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Kimchi_backend.Pasta.Basic.Fp.Stable.V1.t
        [@@deriving sexp, compare, equal, hash, yojson]

        let to_latest = Fn.id
      end
    end]
  end

  module Tree = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Kimchi_backend.Pasta.Basic.Fp.Stable.V1.t
        [@@deriving sexp, compare, equal, hash, yojson]

        let to_latest = Fn.id
      end
    end]
  end
end

module Make_digest_str
    (T : Mina_wire_types.Mina_base.Zkapp_command.Digest_concrete) :
  Make_digest_sig(T).S = struct
  module M = struct
    open Pickles.Impls.Step.Field
    module Checked = Pickles.Impls.Step.Field

    let typ = typ

    let constant = constant
  end

  module Account_update = struct
    include Make_digest_types.Account_update
    include M

    module Checked = struct
      include Checked

      let create = Account_update.Checked.digest

      let create_body = Account_update.Body.Checked.digest
    end

    let create : ?chain:Mina_signature_kind.t -> Account_update.t -> t =
      Account_update.digest

    let create_body : ?chain:Mina_signature_kind.t -> Account_update.Body.t -> t
        =
      Account_update.Body.digest
  end

  module Forest = struct
    include Make_digest_types.Forest
    include M

    module Checked = struct
      include Checked

      let empty = constant empty

      let cons hash h_tl =
        Random_oracle.Checked.hash ~init:Hash_prefix_states.account_update_cons
          [| hash; h_tl |]
    end

    let empty = empty

    let cons hash h_tl =
      Random_oracle.hash ~init:Hash_prefix_states.account_update_cons
        [| hash; h_tl |]
  end

  module Tree = struct
    include Make_digest_types.Tree
    include M

    module Checked = struct
      include Checked

      let create ~(account_update : Account_update.Checked.t)
          ~(calls : Forest.Checked.t) =
        Random_oracle.Checked.hash ~init:Hash_prefix_states.account_update_node
          [| (account_update :> t); (calls :> t) |]
    end

    let create ({ account_update = _; calls; account_update_digest } : _ tree) =
      let stack_hash =
        match calls with [] -> empty | e :: _ -> e.stack_hash
      in
      Random_oracle.hash ~init:Hash_prefix_states.account_update_node
        [| account_update_digest; stack_hash |]
  end
end

module Digest =
  Mina_wire_types.Mina_base.Zkapp_command.Digest_make
    (Make_digest_sig)
    (Make_digest_str)

let fold = Tree.fold_forest

let iteri t ~(f : int -> 'a -> unit) : unit =
  let (_ : int) = fold t ~init:0 ~f:(fun acc x -> f acc x ; acc + 1) in
  ()

[%%versioned
module Stable = struct
  module V1 = struct
    type ('account_update, 'account_update_digest, 'digest) t =
      ( ('account_update, 'account_update_digest, 'digest) Tree.Stable.V1.t
      , 'digest )
      With_stack_hash.Stable.V1.t
      list
    [@@deriving sexp, compare, equal, hash, yojson]

    let to_latest = Fn.id
  end
end]

module Shape = struct
  module I = struct
    type t = int

    let quickcheck_shrinker = Quickcheck.Shrinker.empty ()

    let quickcheck_generator = [%quickcheck.generator: int]

    let quickcheck_observer = [%quickcheck.observer: int]
  end

  type t = Node of (I.t * t) list [@@deriving quickcheck]
end

let rec shape (t : _ t) : Shape.t =
  Node (List.mapi t ~f:(fun i { elt; stack_hash = _ } -> (i, shape elt.calls)))

let match_up (type a b) (xs : a list) (ys : (int * b) list) : (a * b) list =
  let rec go i_curr xs ys =
    match (xs, ys) with
    | [], [] ->
        []
    | x :: xs', (i, y) :: ys' ->
        if i_curr = i then (x, y) :: go (i_curr + 1) xs' ys'
        else if i_curr < i then go (i_curr + 1) xs' ys'
        else assert false
    | [], _ :: _ ->
        assert false
    | _ :: _, [] ->
        []
  in
  go 0 xs ys

let rec mask (t : ('p, 'h1, unit) t) (Node shape : Shape.t) : ('p, 'h1, unit) t
    =
  List.map (match_up t shape)
    ~f:(fun ({ With_stack_hash.elt = t_sub; stack_hash = () }, shape_sub) ->
      { With_stack_hash.elt = { t_sub with calls = mask t_sub.calls shape_sub }
      ; stack_hash = ()
      } )

let rec of_account_updates_map ~(f : 'p1 -> 'p2)
    ~(account_update_depth : 'p1 -> int) (account_updates : 'p1 list) :
    ('p2, unit, unit) t =
  match account_updates with
  | [] ->
      []
  | p :: ps ->
      let depth = account_update_depth p in
      let children, siblings =
        List.split_while ps ~f:(fun p' -> account_update_depth p' > depth)
      in
      { With_stack_hash.elt =
          { Tree.account_update = f p
          ; account_update_digest = ()
          ; calls = of_account_updates_map ~f ~account_update_depth children
          }
      ; stack_hash = ()
      }
      :: of_account_updates_map ~f ~account_update_depth siblings

let of_account_updates ~account_update_depth account_updates =
  of_account_updates_map ~f:Fn.id ~account_update_depth account_updates

let to_account_updates_map ~f (xs : _ t) =
  let rec collect depth (xs : _ t) acc =
    match xs with
    | [] ->
        acc
    | { elt = { account_update; calls; account_update_digest = _ }
      ; stack_hash = _
      }
      :: xs ->
        f ~depth account_update :: acc
        |> collect (depth + 1) calls
        |> collect depth xs
  in
  List.rev (collect 0 xs [])

let to_account_updates xs =
  to_account_updates_map ~f:(fun ~depth:_ account_update -> account_update) xs

let hd_account_update (xs : _ t) =
  match xs with
  | [] ->
      None
  | { elt = { account_update; calls = _; account_update_digest = _ }
    ; stack_hash = _
    }
    :: _ ->
      Some account_update

let map = Tree.map_forest

let mapi = Tree.mapi_forest

let mapi_with_trees = Tree.mapi_forest_with_trees

let deferred_mapi = Tree.deferred_mapi_forest

let to_zkapp_command_with_hashes_list (xs : _ t) =
  let rec collect (xs : _ t) acc =
    match xs with
    | [] ->
        acc
    | { elt = { account_update; calls; account_update_digest = _ }; stack_hash }
      :: xs ->
        (account_update, stack_hash) :: acc |> collect calls |> collect xs
  in
  List.rev (collect xs [])

let hash_cons hash h_tl =
  Random_oracle.hash ~init:Hash_prefix_states.account_update_cons
    [| hash; h_tl |]

let hash = function
  | [] ->
      Digest.Forest.empty
  | x :: _ ->
      With_stack_hash.stack_hash x

let cons_tree tree (forest : _ t) : _ t =
  { elt = tree
  ; stack_hash = Digest.Forest.cons (Digest.Tree.create tree) (hash forest)
  }
  :: forest

let cons_aux (type p) ~(digest_account_update : p -> _) ?(calls = [])
    (account_update : p) (xs : _ t) : _ t =
  let account_update_digest = digest_account_update account_update in
  let tree : _ Tree.t = { account_update; account_update_digest; calls } in
  cons_tree tree xs

let cons ?calls (account_update : Account_update.t) xs =
  cons_aux ~digest_account_update:Digest.Account_update.create ?calls
    account_update xs

let rec accumulate_hashes ~hash_account_update (xs : _ t) =
  let go = accumulate_hashes ~hash_account_update in
  match xs with
  | [] ->
      []
  | { elt = { account_update; calls; account_update_digest = _ }
    ; stack_hash = _
    }
    :: xs ->
      let calls = go calls in
      let xs = go xs in
      let node =
        { Tree.account_update
        ; calls
        ; account_update_digest = hash_account_update account_update
        }
      in
      let node_hash = Digest.Tree.create node in
      { elt = node; stack_hash = Digest.Forest.cons node_hash (hash xs) } :: xs

let accumulate_hashes' (type a b) (xs : (Account_update.t, a, b) t) :
    (Account_update.t, Digest.Account_update.t, Digest.Forest.t) t =
  let hash_account_update (p : Account_update.t) =
    Digest.Account_update.create p
  in
  accumulate_hashes ~hash_account_update xs

let accumulate_hashes_predicated xs =
  accumulate_hashes ~hash_account_update:Digest.Account_update.create xs

module With_hashes_and_data = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'data t =
        ( Account_update.Stable.V1.t * 'data
        , Digest.Account_update.Stable.V1.t
        , Digest.Forest.Stable.V1.t )
        Stable.V1.t
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  let empty = Digest.Forest.empty

  let hash_account_update ((p : Account_update.t), _) =
    Digest.Account_update.create p

  let accumulate_hashes xs : _ t = accumulate_hashes ~hash_account_update xs

  let of_zkapp_command_simple_list (xs : (Account_update.Simple.t * 'a) list) :
      _ t =
    of_account_updates xs
      ~account_update_depth:(fun ((p : Account_update.Simple.t), _) ->
        p.body.call_depth )
    |> map ~f:(fun (p, x) -> (Account_update.of_simple p, x))
    |> accumulate_hashes

  let of_account_updates (xs : (Account_update.Graphql_repr.t * 'a) list) : _ t
      =
    of_account_updates_map
      ~account_update_depth:(fun ((p : Account_update.Graphql_repr.t), _) ->
        p.body.call_depth )
      ~f:(fun (p, x) -> (Account_update.of_graphql_repr p, x))
      xs
    |> accumulate_hashes

  let to_account_updates (x : _ t) = to_account_updates x

  let to_zkapp_command_with_hashes_list (x : _ t) =
    to_zkapp_command_with_hashes_list x

  let account_updates_hash' xs = of_account_updates xs |> hash

  let account_updates_hash xs =
    List.map ~f:(fun x -> (x, ())) xs |> account_updates_hash'
end

module With_hashes = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Account_update.Stable.V1.t
        , Digest.Account_update.Stable.V1.t
        , Digest.Forest.Stable.V1.t )
        Stable.V1.t
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  let empty = Digest.Forest.empty

  let hash_account_update (p : Account_update.t) =
    Digest.Account_update.create p

  let accumulate_hashes xs : t = accumulate_hashes ~hash_account_update xs

  let of_zkapp_command_simple_list (xs : Account_update.Simple.t list) : t =
    of_account_updates xs
      ~account_update_depth:(fun (p : Account_update.Simple.t) ->
        p.body.call_depth )
    |> map ~f:Account_update.of_simple
    |> accumulate_hashes

  let of_account_updates (xs : Account_update.Graphql_repr.t list) : t =
    of_account_updates_map
      ~account_update_depth:(fun (p : Account_update.Graphql_repr.t) ->
        p.body.call_depth )
      ~f:(fun p -> Account_update.of_graphql_repr p)
      xs
    |> accumulate_hashes

  let to_account_updates (x : t) = to_account_updates x

  let to_zkapp_command_with_hashes_list (x : t) =
    to_zkapp_command_with_hashes_list x

  let account_updates_hash' xs = of_account_updates xs |> hash

  let account_updates_hash xs =
    List.map ~f:(fun x -> x) xs |> account_updates_hash'
end

let is_empty : _ t -> bool = List.is_empty

let to_list (type p) (t : (p, _, _) t) : p list =
  List.rev @@ fold t ~init:[] ~f:(fun acc p -> p :: acc)

let exists (type p) (t : (p, _, _) t) ~(f : p -> bool) : bool =
  with_return (fun { return } ->
      fold t ~init:() ~f:(fun () p -> if f p then return true else ()) ;
      false )
