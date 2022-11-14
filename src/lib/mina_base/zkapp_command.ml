open Core_kernel
open Signature_lib

let add_caller (p : Account_update.Wire.t) caller : Account_update.t =
  let add_caller_body (p : Account_update.Body.Wire.t) caller :
      Account_update.Body.t =
    { public_key = p.public_key
    ; token_id = p.token_id
    ; update = p.update
    ; balance_change = p.balance_change
    ; increment_nonce = p.increment_nonce
    ; events = p.events
    ; sequence_events = p.sequence_events
    ; call_data = p.call_data
    ; preconditions = p.preconditions
    ; use_full_commitment = p.use_full_commitment
    ; caller
    ; authorization_kind = p.authorization_kind
    }
  in
  { body = add_caller_body p.body caller; authorization = p.authorization }

let add_caller_simple (p : Account_update.Simple.t) caller : Account_update.t =
  let add_caller_body (p : Account_update.Body.Simple.t) caller :
      Account_update.Body.t =
    { public_key = p.public_key
    ; token_id = p.token_id
    ; update = p.update
    ; balance_change = p.balance_change
    ; increment_nonce = p.increment_nonce
    ; events = p.events
    ; sequence_events = p.sequence_events
    ; call_data = p.call_data
    ; preconditions = p.preconditions
    ; use_full_commitment = p.use_full_commitment
    ; caller
    ; authorization_kind = p.authorization_kind
    }
  in
  { body = add_caller_body p.body caller; authorization = p.authorization }

module Call_forest = struct
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
        ~f:(fun
             acc
             { elt = elt1; stack_hash = _ }
             { elt = elt2; stack_hash = _ }
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
      let l, calls = mapi_forest_with_trees' ~i:(i + 1) t.calls ~f in
      ( l
      , { calls
        ; account_update = f i t.account_update t
        ; account_update_digest = t.account_update_digest
        } )

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
      , { calls
        ; account_update
        ; account_update_digest = t.account_update_digest
        } )

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
      let stack_hash =
        match calls with [] -> empty | e :: _ -> e.stack_hash
      in
      Random_oracle.hash ~init:Hash_prefix_states.account_update_node
        [| account_update_digest; stack_hash |]
  end

  type ('a, 'b, 'c) tree = ('a, 'b, 'c) Tree.t

  module type Digest_intf = sig
    module Account_update : sig
      include Digest_intf.S

      module Checked : sig
        include Digest_intf.S_checked

        val create : Account_update.Checked.t -> t
      end

      include Digest_intf.S_aux with type t := t and type checked := Checked.t

      val create : Account_update.t -> t
    end

    module rec Forest : sig
      include Digest_intf.S

      module Checked : sig
        include Digest_intf.S_checked

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
      [%%versioned
      module Stable = struct
        module V1 = struct
          type t = Kimchi_backend.Pasta.Basic.Fp.Stable.V1.t
          [@@deriving sexp, compare, equal, hash, yojson]

          let to_latest = Fn.id
        end
      end]

      include M

      module Checked = struct
        include Checked

        let create = Account_update.Checked.digest
      end

      let create : Account_update.t -> t = Account_update.digest
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

      include M

      module Checked = struct
        include Checked

        let cons hash h_tl =
          Random_oracle.Checked.hash
            ~init:Hash_prefix_states.account_update_cons [| hash; h_tl |]
      end

      let empty = empty

      let cons hash h_tl =
        Random_oracle.hash ~init:Hash_prefix_states.account_update_cons
          [| hash; h_tl |]
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

      include M

      module Checked = struct
        include Checked

        let create ~(account_update : Account_update.Checked.t)
            ~(calls : Forest.Checked.t) =
          Random_oracle.Checked.hash
            ~init:Hash_prefix_states.account_update_node
            [| (account_update :> t); (calls :> t) |]
      end

      let create ({ account_update = _; calls; account_update_digest } : _ tree)
          =
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

  let rec mask (t : ('p, 'h1, unit) t) (Node shape : Shape.t) :
      ('p, 'h1, unit) t =
    List.map (match_up t shape)
      ~f:(fun ({ With_stack_hash.elt = t_sub; stack_hash = () }, shape_sub) ->
        { With_stack_hash.elt =
            { t_sub with calls = mask t_sub.calls shape_sub }
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

  let%test_unit "Account_update_or_stack.of_zkapp_command_list" =
    let zkapp_command_list_1 = [ 0; 0; 0; 0 ] in
    let node i calls =
      { With_stack_hash.elt =
          { Tree.calls; account_update = i; account_update_digest = () }
      ; stack_hash = ()
      }
    in
    let zkapp_command_list_1_res : (int, unit, unit) t =
      let n0 = node 0 [] in
      [ n0; n0; n0; n0 ]
    in
    let f_index = mapi ~f:(fun i _p -> i) in
    [%test_eq: (int, unit, unit) t]
      (of_account_updates ~account_update_depth:Fn.id zkapp_command_list_1)
      zkapp_command_list_1_res ;
    let zkapp_command_list1_index : (int, unit, unit) t =
      let n i = node i [] in
      [ n 0; n 1; n 2; n 3 ]
    in
    [%test_eq: (int, unit, unit) t]
      ( of_account_updates ~account_update_depth:Fn.id zkapp_command_list_1
      |> f_index )
      zkapp_command_list1_index ;
    [%test_eq: int list]
      (to_account_updates
         (of_account_updates ~account_update_depth:Fn.id zkapp_command_list_1) )
      zkapp_command_list_1 ;
    let zkapp_command_list_2 = [ 0; 0; 1; 1 ] in
    let zkapp_command_list_2_res =
      [ node 0 []; node 0 [ node 1 []; node 1 [] ] ]
    in
    let zkapp_command_list_2_index =
      [ node 0 []; node 1 [ node 2 []; node 3 [] ] ]
    in
    [%test_eq: (int, unit, unit) t]
      (of_account_updates ~account_update_depth:Fn.id zkapp_command_list_2)
      zkapp_command_list_2_res ;
    [%test_eq: (int, unit, unit) t]
      ( of_account_updates ~account_update_depth:Fn.id zkapp_command_list_2
      |> f_index )
      zkapp_command_list_2_index ;
    [%test_eq: int list]
      (to_account_updates
         (of_account_updates ~account_update_depth:Fn.id zkapp_command_list_2) )
      zkapp_command_list_2 ;
    let zkapp_command_list_3 = [ 0; 0; 1; 0 ] in
    let zkapp_command_list_3_res =
      [ node 0 []; node 0 [ node 1 [] ]; node 0 [] ]
    in
    let zkapp_command_list_3_index =
      [ node 0 []; node 1 [ node 2 [] ]; node 3 [] ]
    in
    [%test_eq: (int, unit, unit) t]
      (of_account_updates ~account_update_depth:Fn.id zkapp_command_list_3)
      zkapp_command_list_3_res ;
    [%test_eq: (int, unit, unit) t]
      ( of_account_updates ~account_update_depth:Fn.id zkapp_command_list_3
      |> f_index )
      zkapp_command_list_3_index ;
    [%test_eq: int list]
      (to_account_updates
         (of_account_updates ~account_update_depth:Fn.id zkapp_command_list_3) )
      zkapp_command_list_3 ;
    let zkapp_command_list_4 = [ 0; 1; 2; 3; 2; 1; 0 ] in
    let zkapp_command_list_4_res =
      [ node 0 [ node 1 [ node 2 [ node 3 [] ]; node 2 [] ]; node 1 [] ]
      ; node 0 []
      ]
    in
    let zkapp_command_list_4_index =
      [ node 0 [ node 1 [ node 2 [ node 3 [] ]; node 4 [] ]; node 5 [] ]
      ; node 6 []
      ]
    in
    [%test_eq: (int, unit, unit) t]
      (of_account_updates ~account_update_depth:Fn.id zkapp_command_list_4)
      zkapp_command_list_4_res ;
    [%test_eq: (int, unit, unit) t]
      ( of_account_updates ~account_update_depth:Fn.id zkapp_command_list_4
      |> f_index )
      zkapp_command_list_4_index ;
    [%test_eq: int list]
      (to_account_updates
         (of_account_updates ~account_update_depth:Fn.id zkapp_command_list_4) )
      zkapp_command_list_4

  let to_zkapp_command_with_hashes_list (xs : _ t) =
    let rec collect (xs : _ t) acc =
      match xs with
      | [] ->
          acc
      | { elt = { account_update; calls; account_update_digest = _ }
        ; stack_hash
        }
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
        { elt = node; stack_hash = Digest.Forest.cons node_hash (hash xs) }
        :: xs

  let accumulate_hashes' (type a b) (xs : (Account_update.t, a, b) t) :
      (Account_update.t, Digest.Account_update.t, Digest.Forest.t) t =
    let hash_account_update (p : Account_update.t) =
      Digest.Account_update.create p
    in
    accumulate_hashes ~hash_account_update xs

  let accumulate_hashes_predicated xs =
    accumulate_hashes ~hash_account_update:Digest.Account_update.create xs

  (* Delegate_call means, preserve the current caller.
  *)
  let add_callers
      (type account_update account_update_with_caller account_update_digest
      digest id ) (ps : (account_update, account_update_digest, digest) t)
      ~(call_type : account_update -> Account_update.Call_type.t)
      ~(add_caller : account_update -> id -> account_update_with_caller)
      ~(null_id : id) ~(account_update_id : account_update -> id) :
      (account_update_with_caller, account_update_digest, digest) t =
    let module Context = struct
      type t = { caller : id; self : id }
    end in
    let open Context in
    let rec go curr_context ps =
      match ps with
      | { With_stack_hash.elt =
            { Tree.account_update = p; account_update_digest; calls }
        ; stack_hash
        }
        :: ps ->
          let elt =
            let child_context =
              match call_type p with
              | Delegate_call ->
                  curr_context
              | Call ->
                  { caller = curr_context.self; self = account_update_id p }
            in
            let account_update_caller = child_context.caller in
            { Tree.account_update = add_caller p account_update_caller
            ; account_update_digest
            ; calls = go child_context calls
            }
          in
          { With_stack_hash.elt; stack_hash } :: go curr_context ps
      | [] ->
          []
    in
    go { self = null_id; caller = null_id } ps

  let add_callers' (type h1 h2) (ps : (Account_update.Wire.t, h1, h2) t) :
      (Account_update.t, h1, h2) t =
    add_callers ps
      ~call_type:(fun p -> p.body.caller)
      ~add_caller ~null_id:Token_id.default
      ~account_update_id:(fun p ->
        Account_id.(
          derive_token_id ~owner:(create p.body.public_key p.body.token_id)) )

  let add_callers_simple (type h1 h2) (ps : (Account_update.Simple.t, h1, h2) t)
      : (Account_update.t, h1, h2) t =
    add_callers ps
      ~call_type:(fun p -> p.body.caller)
      ~add_caller:add_caller_simple ~null_id:Token_id.default
      ~account_update_id:(fun p ->
        Account_id.(
          derive_token_id ~owner:(create p.body.public_key p.body.token_id)) )

  let remove_callers
      (type account_update_with_caller account_update_without_sender h1 h2 h1'
      h2' id ) ~(map_account_update_digest : h1 -> h1')
      ~(map_stack_hash : h2 -> h2')
      (ps : (account_update_with_caller, h1, h2) t)
      ~(equal_id : id -> id -> bool)
      ~(add_call_type :
            account_update_with_caller
         -> Account_update.Call_type.t
         -> account_update_without_sender ) ~(null_id : id)
      ~(account_update_caller : account_update_with_caller -> id) :
      (account_update_without_sender, h1', h2') t =
    let rec go ~top_level_account_update parent_caller ps =
      let call_type_for_account_update p : Account_update.Call_type.t =
        if top_level_account_update then Call
        else if equal_id parent_caller (account_update_caller p) then
          Delegate_call
        else Call
      in
      match ps with
      | { With_stack_hash.elt =
            { Tree.account_update = p; account_update_digest; calls }
        ; stack_hash
        }
        :: ps ->
          let ty = call_type_for_account_update p in
          { With_stack_hash.elt =
              { Tree.account_update = add_call_type p ty
              ; account_update_digest =
                  map_account_update_digest account_update_digest
              ; calls =
                  go ~top_level_account_update:false (account_update_caller p)
                    calls
              }
          ; stack_hash = map_stack_hash stack_hash
          }
          :: go ~top_level_account_update parent_caller ps
      | [] ->
          []
    in
    go ~top_level_account_update:true null_id ps

  let%test_unit "add_callers and remove_callers" =
    let module P = struct
      type 'a t = { id : int; caller : 'a } [@@deriving compare, sexp]
    end in
    let module With_call_type = struct
      type tmp = (Account_update.Call_type.t P.t, unit, unit) t
      [@@deriving compare, sexp]

      type t = tmp [@@deriving compare, sexp]
    end in
    let null_id = -1 in
    let module With_id = struct
      type tmp = (int P.t, unit, unit) t [@@deriving compare, sexp]

      type t = tmp [@@deriving compare, sexp]
    end in
    let of_tree tree : _ t =
      [ { With_stack_hash.elt = tree; stack_hash = () } ]
    in
    let node id caller calls =
      { Tree.account_update = { P.id; caller }
      ; account_update_digest = ()
      ; calls =
          List.map calls ~f:(fun elt ->
              { With_stack_hash.elt; stack_hash = () } )
      }
    in
    let t : With_call_type.t =
      let open Account_update.Call_type in
      node 0 Call
        [ node 1 Call
            [ node 11 Call [ node 111 Call []; node 112 Delegate_call [] ]
            ; node 12 Delegate_call
                [ node 121 Call []; node 122 Delegate_call [] ]
            ]
        ; node 2 Delegate_call
            [ node 21 Delegate_call
                [ node 211 Call []; node 212 Delegate_call [] ]
            ; node 22 Call [ node 221 Call []; node 222 Delegate_call [] ]
            ]
        ]
      |> of_tree
    in
    let expected_output : With_id.t =
      node 0 null_id
        [ node 1 0
            [ node 11 1 [ node 111 11 []; node 112 1 [] ]
            ; node 12 0 [ node 121 1 []; node 122 0 [] ]
            ]
        ; node 2 null_id
            [ node 21 null_id [ node 211 0 []; node 212 null_id [] ]
            ; node 22 0 [ node 221 22 []; node 222 0 [] ]
            ]
        ]
      |> of_tree
    in
    let open P in
    [%test_eq: With_id.t]
      (add_callers t
         ~call_type:(fun p -> p.caller)
         ~add_caller:(fun p caller : int P.t -> { p with caller })
         ~null_id
         ~account_update_id:(fun p -> p.id) )
      expected_output ;
    [%test_eq: With_call_type.t]
      (remove_callers expected_output ~equal_id:Int.equal
         ~map_account_update_digest:Fn.id ~map_stack_hash:Fn.id
         ~add_call_type:(fun p call_type -> { p with caller = call_type })
         ~null_id
         ~account_update_caller:(fun p -> p.caller) )
      t

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

    let of_zkapp_command_simple_list (xs : (Account_update.Simple.t * 'a) list)
        : _ t =
      of_account_updates xs
        ~account_update_depth:(fun ((p : Account_update.Simple.t), _) ->
          p.body.call_depth )
      |> add_callers
           ~call_type:(fun ((p : Account_update.Simple.t), _) -> p.body.caller)
           ~add_caller:(fun (p, x) id -> (add_caller_simple p id, x))
           ~null_id:Token_id.default
           ~account_update_id:(fun ((p : Account_update.Simple.t), _) ->
             Account_id.(
               derive_token_id ~owner:(create p.body.public_key p.body.token_id))
             )
      |> accumulate_hashes

    let of_account_updates (xs : (Account_update.Graphql_repr.t * 'a) list) :
        _ t =
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
      |> add_callers
           ~call_type:(fun (p : Account_update.Simple.t) -> p.body.caller)
           ~add_caller:(fun p id -> add_caller_simple p id)
           ~null_id:Token_id.default
           ~account_update_id:(fun (p : Account_update.Simple.t) ->
             Account_id.(
               derive_token_id ~owner:(create p.body.public_key p.body.token_id))
             )
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
end

module Graphql_repr = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { fee_payer : Account_update.Fee_payer.Stable.V1.t
        ; account_updates : Account_update.Graphql_repr.Stable.V1.t list
        ; memo : Signed_command_memo.Stable.V1.t
        }
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end
  end]
end

module Simple = struct
  (* For easily constructing values *)
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { fee_payer : Account_update.Fee_payer.Stable.V1.t
        ; account_updates : Account_update.Simple.Stable.V1.t list
        ; memo : Signed_command_memo.Stable.V1.t
        }
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end
  end]
end

module Digest = Call_forest.Digest

module T = struct
  [%%versioned_binable
  module Stable = struct
    [@@@with_top_version_tag]

    (* DO NOT DELETE VERSIONS!
       so we can always get transaction hashes from old transaction ids
       the version linter should be checking this

       IF YOU CREATE A NEW VERSION:
       update Transaction_hash.hash_of_transaction_id to handle it
       add hash_zkapp_command_vn for that version
    *)

    module V1 = struct
      type t = Mina_wire_types.Mina_base.Zkapp_command.V1.t =
        { fee_payer : Account_update.Fee_payer.Stable.V1.t
        ; account_updates :
            ( Account_update.Stable.V1.t
            , Digest.Account_update.Stable.V1.t
            , Digest.Forest.Stable.V1.t )
            Call_forest.Stable.V1.t
        ; memo : Signed_command_memo.Stable.V1.t
        }
      [@@deriving annot, sexp, compare, equal, hash, yojson, fields]

      let to_latest = Fn.id

      module Wire = struct
        [%%versioned
        module Stable = struct
          module V1 = struct
            type t =
              { fee_payer : Account_update.Fee_payer.Stable.V1.t
              ; account_updates :
                  ( Account_update.Wire.Stable.V1.t
                  , unit
                  , unit )
                  Call_forest.Stable.V1.t
              ; memo : Signed_command_memo.Stable.V1.t
              }
            [@@deriving sexp, compare, equal, hash, yojson]

            let to_latest = Fn.id
          end
        end]

        let check (t : t) : unit =
          List.iter t.account_updates ~f:(fun p ->
              assert (
                Account_update.Call_type.equal p.elt.account_update.body.caller
                  Call ) )

        let of_graphql_repr (t : Graphql_repr.t) : t =
          { fee_payer = t.fee_payer
          ; memo = t.memo
          ; account_updates =
              Call_forest.of_account_updates_map t.account_updates
                ~f:Account_update.of_graphql_repr
                ~account_update_depth:(fun (p : Account_update.Graphql_repr.t)
                                      -> p.body.call_depth )
              |> Call_forest.remove_callers ~equal_id:Token_id.equal
                   ~map_account_update_digest:ignore ~map_stack_hash:ignore
                   ~add_call_type:Account_update.to_wire
                   ~null_id:Token_id.default ~account_update_caller:(fun p ->
                     p.body.caller )
          }

        let to_graphql_repr (t : t) : Graphql_repr.t =
          { fee_payer = t.fee_payer
          ; memo = t.memo
          ; account_updates =
              t.account_updates
              |> Call_forest.add_callers
                   ~call_type:(fun (p : Account_update.Wire.t) -> p.body.caller)
                   ~add_caller ~null_id:Token_id.default
                   ~account_update_id:(fun (p : Account_update.Wire.t) ->
                     Account_id.(
                       derive_token_id
                         ~owner:(create p.body.public_key p.body.token_id)) )
              |> Call_forest.to_account_updates_map
                   ~f:(fun ~depth account_update ->
                     Account_update.to_graphql_repr account_update
                       ~call_depth:depth )
          }

        let gen =
          let open Quickcheck.Generator in
          let open Let_syntax in
          let gen_call_forest =
            let%map xs =
              fixed_point (fun self ->
                  let%bind calls_length = small_non_negative_int in
                  list_with_length calls_length
                    (let%map account_update = Account_update.Wire.gen
                     and calls = self in
                     { With_stack_hash.stack_hash = ()
                     ; elt =
                         { Call_forest.Tree.account_update
                         ; account_update_digest = ()
                         ; calls
                         }
                     } ) )
            in
            (* All top level zkapp_command should be "Call" not "Delegate_call" *)
            List.map xs
              ~f:
                (With_stack_hash.map
                   ~f:(fun (t : (Account_update.Wire.t, _, _) Call_forest.Tree.t)
                      ->
                     { t with
                       account_update =
                         { t.account_update with
                           body = { t.account_update.body with caller = Call }
                         }
                     } ) )
          in
          let open Quickcheck.Let_syntax in
          let%map fee_payer = Account_update.Fee_payer.gen
          and account_updates = gen_call_forest
          and memo = Signed_command_memo.gen in
          { fee_payer; account_updates; memo }

        let shrinker : t Quickcheck.Shrinker.t =
          Quickcheck.Shrinker.create (fun t ->
              let shape = Call_forest.shape t.account_updates in
              Sequence.map
                (Quickcheck.Shrinker.shrink
                   Call_forest.Shape.quickcheck_shrinker shape )
                ~f:(fun shape' ->
                  { t with
                    account_updates = Call_forest.mask t.account_updates shape'
                  } ) )
      end

      let of_wire (w : Wire.t) : t =
        { fee_payer = w.fee_payer
        ; memo = w.memo
        ; account_updates =
            w.account_updates
            |> Call_forest.add_callers
                 ~call_type:(fun (p : Account_update.Wire.t) -> p.body.caller)
                 ~add_caller ~null_id:Token_id.default
                 ~account_update_id:(fun (p : Account_update.Wire.t) ->
                   Account_id.(
                     derive_token_id
                       ~owner:(create p.body.public_key p.body.token_id)) )
            |> Call_forest.accumulate_hashes
                 ~hash_account_update:(fun (p : Account_update.t) ->
                   Digest.Account_update.create p )
        }

      let to_wire (t : t) : Wire.t =
        { fee_payer = t.fee_payer
        ; memo = t.memo
        ; account_updates =
            Call_forest.remove_callers ~equal_id:Token_id.equal
              ~map_account_update_digest:ignore ~map_stack_hash:ignore
              ~add_call_type:Account_update.to_wire ~null_id:Token_id.default
              ~account_update_caller:(fun p -> p.body.caller)
              t.account_updates
        }

      include
        Binable.Of_binable_without_uuid
          (Wire.Stable.V1)
          (struct
            type nonrec t = t

            let of_binable t = Wire.check t ; of_wire t

            let to_binable = to_wire
          end)
    end
  end]
end

include T

[%%define_locally Stable.Latest.(of_wire, to_wire)]

let of_simple (w : Simple.t) : t =
  { fee_payer = w.fee_payer
  ; memo = w.memo
  ; account_updates =
      Call_forest.of_account_updates w.account_updates
        ~account_update_depth:(fun (p : Account_update.Simple.t) ->
          p.body.call_depth )
      |> Call_forest.add_callers
           ~call_type:(fun (p : Account_update.Simple.t) -> p.body.caller)
           ~add_caller:add_caller_simple ~null_id:Token_id.default
           ~account_update_id:(fun (p : Account_update.Simple.t) ->
             Account_id.(
               derive_token_id ~owner:(create p.body.public_key p.body.token_id))
             )
      |> Call_forest.accumulate_hashes
           ~hash_account_update:(fun (p : Account_update.t) ->
             Digest.Account_update.create p )
  }

let to_simple (t : t) : Simple.t =
  { fee_payer = t.fee_payer
  ; memo = t.memo
  ; account_updates =
      Call_forest.remove_callers ~equal_id:Token_id.equal
        ~map_account_update_digest:ignore ~map_stack_hash:ignore
        ~add_call_type:(fun { body = b; authorization } call_type ->
          { Account_update.Simple.authorization
          ; body =
              { public_key = b.public_key
              ; token_id = b.token_id
              ; update = b.update
              ; balance_change = b.balance_change
              ; increment_nonce = b.increment_nonce
              ; events = b.events
              ; sequence_events = b.sequence_events
              ; call_data = b.call_data
              ; preconditions = b.preconditions
              ; use_full_commitment = b.use_full_commitment
              ; caller = call_type
              ; call_depth = 0
              ; authorization_kind = b.authorization_kind
              }
          } )
        ~null_id:Token_id.default
        ~account_update_caller:(fun (p : Account_update.t) -> p.body.caller)
        t.account_updates
      |> Call_forest.to_account_updates_map
           ~f:(fun ~depth (p : Account_update.Simple.t) ->
             { p with body = { p.body with call_depth = depth } } )
  }

let%test_unit "wire embedded in t" =
  let module Wire = Stable.Latest.Wire in
  Quickcheck.test ~trials:10 ~shrinker:Wire.shrinker Wire.gen ~f:(fun w ->
      [%test_eq: Wire.t] (to_wire (of_wire w)) w )

let%test_unit "wire embedded in graphql" =
  let module Wire = Stable.Latest.Wire in
  Quickcheck.test ~shrinker:Wire.shrinker Wire.gen ~f:(fun w ->
      [%test_eq: Wire.t] (Wire.of_graphql_repr (Wire.to_graphql_repr w)) w )

let zkapp_command (t : t) : _ Call_forest.t =
  let p = t.fee_payer in
  let body = Account_update.Body.of_fee_payer p.body in
  let fee_payer : Account_update.t =
    let p = t.fee_payer in
    { authorization = Control.Signature p.authorization; body }
  in
  Call_forest.cons fee_payer t.account_updates

let fee (t : t) : Currency.Fee.t = t.fee_payer.body.fee

let fee_payer_account_update ({ fee_payer; _ } : t) = fee_payer

let applicable_at_nonce (t : t) : Account.Nonce.t =
  (fee_payer_account_update t).body.nonce

let target_nonce_on_success (t : t) : Account.Nonce.t =
  let base_nonce = Account.Nonce.succ (applicable_at_nonce t) in
  let fee_payer_pubkey = t.fee_payer.body.public_key in
  let fee_payer_account_update_increments =
    List.count (Call_forest.to_list t.account_updates) ~f:(fun p ->
        Public_key.Compressed.equal p.body.public_key fee_payer_pubkey
        && p.body.increment_nonce )
  in
  Account.Nonce.add base_nonce
    (Account.Nonce.of_int fee_payer_account_update_increments)

let nonce_increments (t : t) : int Public_key.Compressed.Map.t =
  let base_increments =
    Public_key.Compressed.Map.of_alist_exn [ (t.fee_payer.body.public_key, 1) ]
  in
  List.fold_left (Call_forest.to_list t.account_updates) ~init:base_increments
    ~f:(fun incr_map account_update ->
      if account_update.body.increment_nonce then
        Map.update incr_map account_update.body.public_key
          ~f:(Option.value_map ~default:1 ~f:(( + ) 1))
      else incr_map )

let fee_token (_t : t) = Token_id.default

let fee_payer (t : t) =
  Account_id.create t.fee_payer.body.public_key (fee_token t)

let account_updates_list (t : t) : Account_update.t list =
  Call_forest.fold t.account_updates ~init:[] ~f:(Fn.flip List.cons) |> List.rev

let zkapp_command_list (t : t) : Account_update.t list =
  Call_forest.fold t.account_updates
    ~init:[ Account_update.of_fee_payer (fee_payer_account_update t) ]
    ~f:(Fn.flip List.cons)
  |> List.rev

let fee_excess (t : t) =
  Fee_excess.of_single (fee_token t, Currency.Fee.Signed.of_unsigned (fee t))

let accounts_accessed (t : t) (status : Transaction_status.t) =
  match status with
  | Applied ->
      Call_forest.fold t.account_updates
        ~init:[ fee_payer t ]
        ~f:(fun acc p -> Account_update.account_id p :: acc)
      |> List.rev |> List.stable_dedup
  | Failed _ ->
      [ fee_payer t ]

let accounts_referenced (t : t) = accounts_accessed t Applied

let fee_payer_pk (t : t) = t.fee_payer.body.public_key

let value_if b ~then_ ~else_ = if b then then_ else else_

module Virtual = struct
  module Bool = struct
    type t = bool

    let true_ = true

    let assert_ _ = ()

    let equal = Bool.equal

    let not = not

    let ( || ) = ( || )

    let ( && ) = ( && )
  end

  module Unit = struct
    type t = unit

    let if_ = value_if
  end

  module Ledger = Unit
  module Account = Unit

  module Amount = struct
    open Currency.Amount

    type nonrec t = t

    let if_ = value_if

    module Signed = Signed

    let zero = zero

    let ( - ) (x1 : t) (x2 : t) : Signed.t =
      Option.value_exn Signed.(of_unsigned x1 + negate (of_unsigned x2))

    let ( + ) (x1 : t) (x2 : t) : t = Option.value_exn (add x1 x2)

    let add_signed (x1 : t) (x2 : Signed.t) : t =
      let y = Option.value_exn Signed.(of_unsigned x1 + x2) in
      match y.sgn with Pos -> y.magnitude | Neg -> failwith "add_signed"
  end

  module Token_id = struct
    include Token_id

    let if_ = value_if
  end

  module Zkapp_command = struct
    type t = Account_update.t list

    let if_ = value_if

    type account_update = Account_update.t

    let empty = []

    let is_empty = List.is_empty

    let pop (t : t) = match t with [] -> failwith "pop" | p :: t -> (p, t)
  end
end

module Verifiable = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { fee_payer : Account_update.Fee_payer.Stable.V1.t
        ; account_updates :
            ( Side_loaded_verification_key.Stable.V2.t
            , Zkapp_basic.F.Stable.V1.t )
            With_hash.Stable.V1.t
            option
            Call_forest.With_hashes_and_data.Stable.V1.t
        ; memo : Signed_command_memo.Stable.V1.t
        }
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end
  end]
end

let of_verifiable (t : Verifiable.t) : t =
  { fee_payer = t.fee_payer
  ; account_updates = Call_forest.map t.account_updates ~f:fst
  ; memo = t.memo
  }

module Transaction_commitment = struct
  module Stable = Kimchi_backend.Pasta.Basic.Fp.Stable

  type t = (Stable.Latest.t[@deriving sexp])

  let sexp_of_t = Stable.Latest.sexp_of_t

  let t_of_sexp = Stable.Latest.t_of_sexp

  let empty = Outside_hash_image.t

  let typ = Snark_params.Tick.Field.typ

  let create ~(account_updates_hash : Digest.Forest.t) : t =
    (account_updates_hash :> t)

  let create_complete (t : t) ~memo_hash
      ~(fee_payer_hash : Digest.Account_update.t) =
    Random_oracle.hash ~init:Hash_prefix.account_update_cons
      [| memo_hash; (fee_payer_hash :> t); t |]

  module Checked = struct
    type t = Pickles.Impls.Step.Field.t

    let create ~(account_updates_hash : Digest.Forest.Checked.t) =
      (account_updates_hash :> t)

    let create_complete (t : t) ~memo_hash
        ~(fee_payer_hash : Digest.Account_update.Checked.t) =
      Random_oracle.Checked.hash ~init:Hash_prefix.account_update_cons
        [| memo_hash; (fee_payer_hash :> t); t |]
  end
end

let account_updates_hash (t : t) = Call_forest.hash t.account_updates

let commitment (t : t) : Transaction_commitment.t =
  Transaction_commitment.create ~account_updates_hash:(account_updates_hash t)

(** This module defines weights for each component of a `Zkapp_command.t` element. *)
module Weight = struct
  let account_update : Account_update.t -> int = fun _ -> 1

  let fee_payer (_fp : Account_update.Fee_payer.t) : int = 1

  let account_updates : (Account_update.t, _, _) Call_forest.t -> int =
    Call_forest.fold ~init:0 ~f:(fun acc p -> acc + account_update p)

  let memo : Signed_command_memo.t -> int = fun _ -> 0
end

let weight (zkapp_command : t) : int =
  let { fee_payer; account_updates; memo } = zkapp_command in
  List.sum
    (module Int)
    ~f:Fn.id
    [ Weight.fee_payer fee_payer
    ; Weight.account_updates account_updates
    ; Weight.memo memo
    ]

module type Valid_intf = sig
  module Verification_key_hash : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type t = Zkapp_basic.F.Stable.V1.t
        [@@deriving sexp, compare, equal, hash, yojson]
      end
    end]
  end

  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = private
        { zkapp_command : T.Stable.V1.t
        ; verification_keys :
            (Account_id.Stable.V2.t * Verification_key_hash.Stable.V1.t) list
        }
      [@@deriving sexp, compare, equal, hash, yojson]
    end
  end]

  val to_valid_unsafe :
    T.t -> [> `If_this_is_used_it_should_have_a_comment_justifying_it of t ]

  val to_valid :
       T.t
    -> ledger:'a
    -> get:('a -> 'b -> Account.t option)
    -> location_of_account:('a -> Account_id.t -> 'b option)
    -> t option

  val of_verifiable : Verifiable.t -> t option

  val forget : t -> T.t
end

module Valid :
  Valid_intf
    with type Stable.V1.t = Mina_wire_types.Mina_base.Zkapp_command.Valid.V1.t =
struct
  module S = Stable

  module Verification_key_hash = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Zkapp_basic.F.Stable.V1.t
        [@@deriving sexp, compare, equal, hash, yojson]

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Mina_wire_types.Mina_base.Zkapp_command.Valid.V1.t =
        { zkapp_command : S.V1.t
        ; verification_keys :
            (Account_id.Stable.V2.t * Verification_key_hash.Stable.V1.t) list
        }
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  let create ~verification_keys zkapp_command : t =
    { zkapp_command; verification_keys }

  let of_verifiable (t : Verifiable.t) : t option =
    let open Option.Let_syntax in
    let tbl = Account_id.Table.create () in
    let%map () =
      Call_forest.fold t.account_updates ~init:(Some ())
        ~f:(fun acc (p, vk_opt) ->
          let%bind _ok = acc in
          let account_id = Account_update.account_id p in
          let%bind () =
            match (p.authorization, p.body.authorization_kind) with
            | None_given, None_given | Proof _, Proof | Signature _, Signature
              ->
                Some ()
            | _ ->
                None
          in
          if Control.(Tag.equal Tag.Proof (Control.tag p.authorization)) then
            let%map { With_hash.hash; _ } = vk_opt in
            Account_id.Table.update tbl account_id ~f:(fun _ -> hash)
          else acc )
    in
    { zkapp_command = of_verifiable t
    ; verification_keys = Account_id.Table.to_alist tbl
    }

  let to_valid_unsafe (t : T.t) :
      [> `If_this_is_used_it_should_have_a_comment_justifying_it of t ] =
    `If_this_is_used_it_should_have_a_comment_justifying_it
      (create t ~verification_keys:[])

  let forget (t : t) : T.t = t.zkapp_command

  let to_valid (t : T.t) ~ledger ~get ~location_of_account : t option =
    let open Option.Let_syntax in
    let find_vk account_id =
      let%bind location = location_of_account ledger account_id in
      let%bind (account : Account.t) = get ledger location in
      let%bind zkapp = account.zkapp in
      zkapp.verification_key
    in
    let tbl = Account_id.Table.create () in
    let%map () =
      Call_forest.fold t.account_updates ~init:(Some ()) ~f:(fun acc p ->
          let%bind _ok = acc in
          let account_id = Account_update.account_id p in
          if Control.(Tag.equal Tag.Proof (Control.tag p.authorization)) then
            Option.map (find_vk account_id) ~f:(fun vk ->
                Account_id.Table.update tbl account_id ~f:(fun _ ->
                    With_hash.hash vk ) )
          else acc )
    in
    create ~verification_keys:(Account_id.Table.to_alist tbl) t
end

[%%define_locally Stable.Latest.(of_yojson, to_yojson)]

(* so transaction ids have a version tag *)
include Codable.Make_base64 (Stable.Latest.With_top_version_tag)

type account_updates =
  (Account_update.t, Digest.Account_update.t, Digest.Forest.t) Call_forest.t

let account_updates_deriver obj =
  let of_zkapp_command_with_depth (ps : Account_update.Graphql_repr.t list) :
      account_updates =
    Call_forest.of_account_updates ps
      ~account_update_depth:(fun (p : Account_update.Graphql_repr.t) ->
        p.body.call_depth )
    |> Call_forest.map ~f:Account_update.of_graphql_repr
    |> Call_forest.accumulate_hashes'
  and to_zkapp_command_with_depth (ps : account_updates) :
      Account_update.Graphql_repr.t list =
    ps
    |> Call_forest.to_account_updates_map ~f:(fun ~depth p ->
           Account_update.to_graphql_repr ~call_depth:depth p )
  in
  let open Fields_derivers_zkapps.Derivers in
  let inner = (list @@ Account_update.Graphql_repr.deriver @@ o ()) @@ o () in
  iso ~map:of_zkapp_command_with_depth ~contramap:to_zkapp_command_with_depth
    inner obj

let deriver obj =
  let open Fields_derivers_zkapps.Derivers in
  let ( !. ) = ( !. ) ~t_fields_annots in
  Fields.make_creator obj
    ~fee_payer:!.Account_update.Fee_payer.deriver
    ~account_updates:!.account_updates_deriver
    ~memo:!.Signed_command_memo.deriver
  |> finish "ZkappCommand" ~t_toplevel_annots

let arg_typ () = Fields_derivers_zkapps.(arg_typ (deriver @@ Derivers.o ()))

let typ () = Fields_derivers_zkapps.(typ (deriver @@ Derivers.o ()))

let to_json x = Fields_derivers_zkapps.(to_json (deriver @@ Derivers.o ())) x

let of_json x = Fields_derivers_zkapps.(of_json (deriver @@ Derivers.o ())) x

let account_updates_of_json x =
  Fields_derivers_zkapps.(
    of_json
      ((list @@ Account_update.Graphql_repr.deriver @@ o ()) @@ derivers ()))
    x

let zkapp_command_to_json x =
  Fields_derivers_zkapps.(to_json (deriver @@ derivers ())) x

let arg_query_string x =
  Fields_derivers_zkapps.Test.Loop.json_to_string_gql @@ to_json x

let dummy =
  let account_update : Account_update.t =
    { body = Account_update.Body.dummy
    ; authorization = Control.dummy_of_tag Signature
    }
  in
  let fee_payer : Account_update.Fee_payer.t =
    { body = Account_update.Body.Fee_payer.dummy
    ; authorization = Signature.dummy
    }
  in
  { fee_payer
  ; account_updates = Call_forest.cons account_update []
  ; memo = Signed_command_memo.empty
  }

module Make_update_group (Input : sig
  type global_state

  type local_state

  type spec

  val zkapp_segment_of_controls : Control.t list -> spec
end) : sig
  module Zkapp_command_intermediate_state : sig
    type state = { global : Input.global_state; local : Input.local_state }

    type t =
      { kind : [ `Same | `New | `Two_new ]
      ; spec : Input.spec
      ; state_before : state
      ; state_after : state
      }
  end

  val group_by_zkapp_command_rev :
       Account_update.t list list
    -> (Input.global_state * Input.local_state) list list
    -> Zkapp_command_intermediate_state.t list
end = struct
  open Input

  module Zkapp_command_intermediate_state = struct
    type state = { global : global_state; local : local_state }

    type t =
      { kind : [ `Same | `New | `Two_new ]
      ; spec : spec
      ; state_before : state
      ; state_after : state
      }
  end

  (** [group_by_zkapp_command_rev zkapp_commands stmtss] identifies before/after pairs of
    statements, corresponding to zkapp_command in [zkapp_commands] which minimize the
    number of snark proofs needed to prove all of the zkapp_command.

    This function is intended to take the zkapp_command from multiple transactions as
    its input, which may be converted from a [Zkapp_command.t list] using
    [List.map ~f:Zkapp_command.zkapp_command]. The [stmtss] argument should be a list of
    the same length, with 1 more state than the number of zkapp_command for each
    transaction.

    For example, two transactions made up of zkapp_command [[p1; p2; p3]] and
    [[p4; p5]] should have the statements [[[s0; s1; s2; s3]; [s3; s4; s5]]],
    where each [s_n] is the state after applying [p_n] on top of [s_{n-1}], and
    where [s0] is the initial state before any of the transactions have been
    applied.

    Each pair is also identified with one of [`Same], [`New], or [`Two_new],
    indicating that the next one ([`New]) or next two ([`Two_new]) [Zkapp_command.t]s
    will need to be passed as part of the snark witness while applying that
    pair.
*)
  let group_by_zkapp_command_rev (zkapp_commands : Account_update.t list list)
      (stmtss : (global_state * local_state) list list) :
      Zkapp_command_intermediate_state.t list =
    let intermediate_state ~kind ~spec ~before ~after =
      { Zkapp_command_intermediate_state.kind
      ; spec
      ; state_before = { global = fst before; local = snd before }
      ; state_after = { global = fst after; local = snd after }
      }
    in
    let rec group_by_zkapp_command_rev
        (zkapp_commands : Account_update.t list list) stmtss acc =
      match (zkapp_commands, stmtss) with
      | ([] | [ [] ]), [ _ ] ->
          (* We've associated statements with all given zkapp_command. *)
          acc
      | [ [ { authorization = a1; _ } ] ], [ [ before; after ] ] ->
          (* There are no later zkapp_command to pair this one with. Prove it on its
             own.
          *)
          intermediate_state ~kind:`Same
            ~spec:(zkapp_segment_of_controls [ a1 ])
            ~before ~after
          :: acc
      | [ []; [ { authorization = a1; _ } ] ], [ [ _ ]; [ before; after ] ] ->
          (* This account_update is part of a new transaction, and there are no later
             zkapp_command to pair it with. Prove it on its own.
          *)
          intermediate_state ~kind:`New
            ~spec:(zkapp_segment_of_controls [ a1 ])
            ~before ~after
          :: acc
      | ( ({ authorization = Proof _ as a1; _ } :: zkapp_command)
          :: zkapp_commands
        , (before :: (after :: _ as stmts)) :: stmtss ) ->
          (* This account_update contains a proof, don't pair it with other zkapp_command. *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`Same
                ~spec:(zkapp_segment_of_controls [ a1 ])
                ~before ~after
            :: acc )
      | ( []
          :: ({ authorization = Proof _ as a1; _ } :: zkapp_command)
             :: zkapp_commands
        , [ _ ] :: (before :: (after :: _ as stmts)) :: stmtss ) ->
          (* This account_update is part of a new transaction, and contains a proof, don't
             pair it with other zkapp_command.
          *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`New
                ~spec:(zkapp_segment_of_controls [ a1 ])
                ~before ~after
            :: acc )
      | ( ({ authorization = a1; _ }
          :: ({ authorization = Proof _; _ } :: _ as zkapp_command) )
          :: zkapp_commands
        , (before :: (after :: _ as stmts)) :: stmtss ) ->
          (* The next account_update contains a proof, don't pair it with this account_update. *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`Same
                ~spec:(zkapp_segment_of_controls [ a1 ])
                ~before ~after
            :: acc )
      | ( ({ authorization = a1; _ } :: ([] as zkapp_command))
          :: (({ authorization = Proof _; _ } :: _) :: _ as zkapp_commands)
        , (before :: (after :: _ as stmts)) :: stmtss ) ->
          (* The next account_update is in the next transaction and contains a proof,
             don't pair it with this account_update.
          *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`Same
                ~spec:(zkapp_segment_of_controls [ a1 ])
                ~before ~after
            :: acc )
      | ( ({ authorization = (Signature _ | None_given) as a1; _ }
          :: { authorization = (Signature _ | None_given) as a2; _ }
             :: zkapp_command )
          :: zkapp_commands
        , (before :: _ :: (after :: _ as stmts)) :: stmtss ) ->
          (* The next two zkapp_command do not contain proofs, and are within the same
             transaction. Pair them.
             Ok to get "use_full_commitment" of [a1] because neither of them
             contain a proof.
          *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`Same
                ~spec:(zkapp_segment_of_controls [ a1; a2 ])
                ~before ~after
            :: acc )
      | ( []
          :: ({ authorization = a1; _ }
             :: ({ authorization = Proof _; _ } :: _ as zkapp_command) )
             :: zkapp_commands
        , [ _ ] :: (before :: (after :: _ as stmts)) :: stmtss ) ->
          (* This account_update is in the next transaction, and the next account_update contains a
             proof, don't pair it with this account_update.
          *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`New
                ~spec:(zkapp_segment_of_controls [ a1 ])
                ~before ~after
            :: acc )
      | ( []
          :: ({ authorization = (Signature _ | None_given) as a1; _ }
             :: { authorization = (Signature _ | None_given) as a2; _ }
                :: zkapp_command )
             :: zkapp_commands
        , [ _ ] :: (before :: _ :: (after :: _ as stmts)) :: stmtss ) ->
          (* The next two zkapp_command do not contain proofs, and are within the same
             new transaction. Pair them.
             Ok to get "use_full_commitment" of [a1] because neither of them
             contain a proof.
          *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`New
                ~spec:(zkapp_segment_of_controls [ a1; a2 ])
                ~before ~after
            :: acc )
      | ( [ { authorization = (Signature _ | None_given) as a1; _ } ]
          :: ({ authorization = (Signature _ | None_given) as a2; _ }
             :: zkapp_command )
             :: zkapp_commands
        , (before :: _after1) :: (_before2 :: (after :: _ as stmts)) :: stmtss )
        ->
          (* The next two zkapp_command do not contain proofs, and the second is within
             a new transaction. Pair them.
             Ok to get "use_full_commitment" of [a1] because neither of them
             contain a proof.
          *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`New
                ~spec:(zkapp_segment_of_controls [ a1; a2 ])
                ~before ~after
            :: acc )
      | ( []
          :: ({ authorization = a1; _ } :: zkapp_command)
             :: (({ authorization = Proof _; _ } :: _) :: _ as zkapp_commands)
        , [ _ ] :: (before :: ([ after ] as stmts)) :: (_ :: _ as stmtss) ) ->
          (* The next transaction contains a proof, and this account_update is in a new
             transaction, don't pair it with the next account_update.
          *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`New
                ~spec:(zkapp_segment_of_controls [ a1 ])
                ~before ~after
            :: acc )
      | ( []
          :: [ { authorization = (Signature _ | None_given) as a1; _ } ]
             :: ({ authorization = (Signature _ | None_given) as a2; _ }
                :: zkapp_command )
                :: zkapp_commands
        , [ _ ]
          :: [ before; _after1 ]
             :: (_before2 :: (after :: _ as stmts)) :: stmtss ) ->
          (* The next two zkapp_command do not contain proofs, the first is within a
             new transaction, and the second is within another new transaction.
             Pair them.
             Ok to get "use_full_commitment" of [a1] because neither of them
             contain a proof.
          *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`Two_new
                ~spec:(zkapp_segment_of_controls [ a1; a2 ])
                ~before ~after
            :: acc )
      | [ [ { authorization = a1; _ } ] ], (before :: after :: _) :: _ ->
          (* This account_update is the final account_update given. Prove it on its own. *)
          intermediate_state ~kind:`Same
            ~spec:(zkapp_segment_of_controls [ a1 ])
            ~before ~after
          :: acc
      | ( [] :: [ { authorization = a1; _ } ] :: [] :: _
        , [ _ ] :: (before :: after :: _) :: _ ) ->
          (* This account_update is the final account_update given, in a new transaction. Prove it
             on its own.
          *)
          intermediate_state ~kind:`New
            ~spec:(zkapp_segment_of_controls [ a1 ])
            ~before ~after
          :: acc
      | _, [] ->
          failwith "group_by_zkapp_command_rev: No statements remaining"
      | ([] | [ [] ]), _ ->
          failwith "group_by_zkapp_command_rev: Unmatched statements remaining"
      | [] :: _, [] :: _ ->
          failwith
            "group_by_zkapp_command_rev: No final statement for current \
             transaction"
      | [] :: _, (_ :: _ :: _) :: _ ->
          failwith
            "group_by_zkapp_command_rev: Unmatched statements for current \
             transaction"
      | [] :: [ _ ] :: _, [ _ ] :: (_ :: _ :: _ :: _) :: _ ->
          failwith
            "group_by_zkapp_command_rev: Unmatched statements for next \
             transaction"
      | [ []; [ _ ] ], [ _ ] :: [ _; _ ] :: _ :: _ ->
          failwith
            "group_by_zkapp_command_rev: Unmatched statements after next \
             transaction"
      | (_ :: _) :: _, ([] | [ _ ]) :: _ | (_ :: _ :: _) :: _, [ _; _ ] :: _ ->
          failwith
            "group_by_zkapp_command_rev: Too few statements remaining for the \
             current transaction"
      | ([] | [ _ ]) :: [] :: _, _ ->
          failwith
            "group_by_zkapp_command_rev: The next transaction has no \
             zkapp_command"
      | [] :: (_ :: _) :: _, _ :: ([] | [ _ ]) :: _
      | [] :: (_ :: _ :: _) :: _, _ :: [ _; _ ] :: _ ->
          failwith
            "group_by_zkapp_command_rev: Too few statements remaining for the \
             next transaction"
      | [ _ ] :: (_ :: _) :: _, _ :: ([] | [ _ ]) :: _ ->
          failwith
            "group_by_zkapp_command_rev: Too few statements remaining for the \
             next transaction"
      | [] :: [ _ ] :: (_ :: _) :: _, _ :: _ :: ([] | [ _ ]) :: _ ->
          failwith
            "group_by_zkapp_command_rev: Too few statements remaining for the \
             transaction after next"
      | ([] | [ _ ]) :: (_ :: _) :: _, [ _ ] ->
          failwith
            "group_by_zkapp_command_rev: No statements given for the next \
             transaction"
      | [] :: [ _ ] :: (_ :: _) :: _, [ _; _ :: _ :: _ ] ->
          failwith
            "group_by_zkapp_command_rev: No statements given for transaction \
             after next"
    in
    group_by_zkapp_command_rev zkapp_commands stmtss []
end

(*Transaction_snark.Zkapp_command_segment.Basic.t*)
type possible_segments = Proved | Signed_single | Signed_pair

module Update_group = Make_update_group (struct
  type local_state = unit

  type global_state = unit

  type spec = possible_segments

  let zkapp_segment_of_controls controls : spec =
    match controls with
    | [ Control.Proof _ ] ->
        Proved
    | [ (Control.Signature _ | Control.None_given) ] ->
        Signed_single
    | [ Control.(Signature _ | None_given); Control.(Signature _ | None_given) ]
      ->
        Signed_pair
    | _ ->
        failwith "zkapp_segment_of_controls: Unsupported combination"
end)

(* Zkapp_command transactions are filtered using this predicate
   - when adding to the transaction pool
   - in incoming blocks
*)
let valid_size ~(genesis_constants : Genesis_constants.t) (t : t) :
    unit Or_error.t =
  let events_elements events =
    List.fold events ~init:0 ~f:(fun acc event -> acc + Array.length event)
  in
  let all_updates, num_event_elements, num_sequence_event_elements =
    Call_forest.fold t.account_updates
      ~init:([ Account_update.of_fee_payer (fee_payer_account_update t) ], 0, 0)
      ~f:(fun (acc, num_event_elements, num_sequence_event_elements)
              (account_update : Account_update.t) ->
        let account_update_evs_elements =
          events_elements account_update.body.events
        in
        let account_update_seq_evs_elements =
          events_elements account_update.body.sequence_events
        in
        ( account_update :: acc
        , num_event_elements + account_update_evs_elements
        , num_sequence_event_elements + account_update_seq_evs_elements ) )
    |> fun (updates, ev, sev) -> (List.rev updates, ev, sev)
  in
  let groups =
    Update_group.group_by_zkapp_command_rev ([] :: [ all_updates ])
      ( [ ((), ()) ]
      :: [ ((), ()) :: List.map all_updates ~f:(fun _ -> ((), ())) ] )
  in
  let proof_segments, signed_singles, signed_pairs =
    List.fold ~init:(0, 0, 0) groups
      ~f:(fun (proof_segments, signed_singles, signed_pairs) { spec; _ } ->
        match spec with
        | Proved ->
            (proof_segments + 1, signed_singles, signed_pairs)
        | Signed_single ->
            (proof_segments, signed_singles + 1, signed_pairs)
        | Signed_pair ->
            (proof_segments, signed_singles, signed_pairs + 1) )
  in
  let proof_cost = genesis_constants.zkapp_proof_update_cost in
  let signed_pair_cost = genesis_constants.zkapp_signed_pair_update_cost in
  let signed_single_cost = genesis_constants.zkapp_signed_single_update_cost in
  let cost_limit = genesis_constants.zkapp_transaction_cost_limit in
  let max_event_elements = genesis_constants.max_event_elements in
  let max_sequence_event_elements =
    genesis_constants.max_sequence_event_elements
  in
  (*10.26*np + 10.08*n2 + 9.14*n1 < 69.45*)
  let zkapp_cost_within_limit =
    Float.(
      (proof_cost * of_int proof_segments)
      + (signed_pair_cost * of_int signed_pairs)
      + (signed_single_cost * of_int signed_singles)
      < cost_limit)
  in
  let valid_event_elements = num_event_elements <= max_event_elements in
  let valid_sequence_event_elements =
    num_sequence_event_elements <= max_sequence_event_elements
  in
  if
    zkapp_cost_within_limit && valid_event_elements
    && valid_sequence_event_elements
  then Ok ()
  else
    let proof_zkapp_command_err =
      if zkapp_cost_within_limit then None
      else Some (sprintf "zkapp transaction too expensive")
    in
    let events_err =
      if valid_event_elements then None
      else
        Some
          (sprintf "too many event elements (%d, max allowed is %d)"
             num_event_elements max_event_elements )
    in
    let sequence_events_err =
      if valid_sequence_event_elements then None
      else
        Some
          (sprintf "too many sequence event elements (%d, max allowed is %d)"
             num_sequence_event_elements max_sequence_event_elements )
    in
    let err_msg =
      List.filter
        [ proof_zkapp_command_err; events_err; sequence_events_err ]
        ~f:Option.is_some
      |> List.map ~f:(fun opt -> Option.value_exn opt)
      |> String.concat ~sep:"; "
    in
    Error (Error.of_string err_msg)

let inner_query =
  lazy
    (Option.value_exn ~message:"Invariant: All projectable derivers are Some"
       Fields_derivers_zkapps.(inner_query (deriver @@ Derivers.o ())) )

let%test_module "Test" =
  ( module struct
    module Fd = Fields_derivers_zkapps.Derivers

    let full = deriver @@ Fd.o ()

    let%test_unit "json roundtrip dummy" =
      [%test_eq: t] dummy (dummy |> Fd.to_json full |> Fd.of_json full)

    let%test_unit "full circuit" =
      Run_in_thread.block_on_async_exn
      @@ fun () -> Fields_derivers_zkapps.Test.Loop.run full dummy

    let%test "latest zkApp version" =
      (* if this test fails, update `Transaction_hash.hash_of_transaction_id`
         for latest version, then update this test
      *)
      Stable.Latest.version = 1
  end )
