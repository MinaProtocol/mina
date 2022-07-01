open Core_kernel

let add_caller (p : Party.Wire.t) caller : Party.t =
  let add_caller_body (p : Party.Body.Wire.t) caller : Party.Body.t =
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
    }
  in
  { body = add_caller_body p.body caller; authorization = p.authorization }

let add_caller_simple (p : Party.Simple.t) caller : Party.t =
  let add_caller_body (p : Party.Body.Simple.t) caller : Party.Body.t =
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
    }
  in
  { body = add_caller_body p.body caller; authorization = p.authorization }

module Call_forest = struct
  let empty = Outside_hash_image.t

  module Tree = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('party, 'party_digest, 'digest) t =
          { party : 'party
          ; party_digest : 'party_digest
          ; calls :
              ( ('party, 'party_digest, 'digest) t
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

    and fold { party; calls; party_digest = _ } ~f ~init =
      fold_forest calls ~f ~init:(f init party)

    let rec fold_forest2_exn (ts1 : (_ t, _) With_stack_hash.t list)
        (ts2 : (_ t, _) With_stack_hash.t list) ~f ~init =
      List.fold2_exn ts1 ts2 ~init
        ~f:(fun
             acc
             { elt = elt1; stack_hash = _ }
             { elt = elt2; stack_hash = _ }
           -> fold2_exn elt1 elt2 ~init:acc ~f )

    and fold2_exn { party = party1; calls = calls1; party_digest = _ }
        { party = party2; calls = calls2; party_digest = _ } ~f ~init =
      fold_forest2_exn calls1 calls2 ~f ~init:(f init party1 party2)

    let iter_forest2_exn ts1 ts2 ~f =
      fold_forest2_exn ts1 ts2 ~init:() ~f:(fun () p1 p2 -> f p1 p2)

    let iter2_exn ts1 ts2 ~f =
      fold2_exn ts1 ts2 ~init:() ~f:(fun () p1 p2 -> f p1 p2)

    let rec mapi_with_trees' ~i (t : _ t) ~f =
      let l, calls = mapi_forest_with_trees' ~i:(i + 1) t.calls ~f in
      (l, { calls; party = f i t.party t; party_digest = t.party_digest })

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

    let mapi' ~i t ~f = mapi_with_trees' ~i t ~f:(fun i party _ -> f i party)

    let mapi_forest' ~i t ~f =
      mapi_forest_with_trees' ~i t ~f:(fun i party _ -> f i party)

    let map_forest ~f t = mapi_forest' ~i:0 ~f:(fun _ x -> f x) t |> snd

    let mapi_forest ~f t = mapi_forest' ~i:0 ~f t |> snd

    let hash { party = _; calls; party_digest } =
      let stack_hash =
        match calls with [] -> empty | e :: _ -> e.stack_hash
      in
      Random_oracle.hash ~init:Hash_prefix_states.party_node
        [| party_digest; stack_hash |]
  end

  type ('a, 'b, 'c) tree = ('a, 'b, 'c) Tree.t

  module Digest : sig
    module Party : sig
      include Digest_intf.S

      module Checked : sig
        include Digest_intf.S_checked

        val create : Party.Checked.t -> t
      end

      include Digest_intf.S_aux with type t := t and type checked := Checked.t

      val create : Party.t -> t
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
          party:Party.Checked.t -> calls:Forest.Checked.t -> Tree.Checked.t
      end

      include Digest_intf.S_aux with type t := t and type checked := Checked.t

      val create : (_, Party.t, Forest.t) tree -> Tree.t
    end
  end = struct
    module M = struct
      open Pickles.Impls.Step.Field
      module Checked = Pickles.Impls.Step.Field

      let typ = typ

      let constant = constant
    end

    module Party = struct
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

        let create = Party.Checked.digest
      end

      let create : Party.t -> t = Party.digest
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
          Random_oracle.Checked.hash ~init:Hash_prefix_states.party_cons
            [| hash; h_tl |]
      end

      let empty = empty

      let cons hash h_tl =
        Random_oracle.hash ~init:Hash_prefix_states.party_cons [| hash; h_tl |]
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

        let create ~(party : Party.Checked.t) ~(calls : Forest.Checked.t) =
          Random_oracle.Checked.hash ~init:Hash_prefix_states.party_node
            [| (party :> t); (calls :> t) |]
      end

      let create ({ party = _; calls; party_digest } : _ tree) =
        let stack_hash =
          match calls with [] -> empty | e :: _ -> e.stack_hash
        in
        Random_oracle.hash ~init:Hash_prefix_states.party_node
          [| party_digest; stack_hash |]
    end
  end

  let fold = Tree.fold_forest

  let iteri t ~(f : int -> 'a -> unit) : unit =
    let (_ : int) = fold t ~init:0 ~f:(fun acc x -> f acc x ; acc + 1) in
    ()

  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('party, 'party_digest, 'digest) t =
        ( ('party, 'party_digest, 'digest) Tree.Stable.V1.t
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

  let rec of_parties_list_map ~(f : 'p1 -> 'p2) ~(party_depth : 'p1 -> int)
      (parties : 'p1 list) : ('p2, unit, unit) t =
    match parties with
    | [] ->
        []
    | p :: ps ->
        let depth = party_depth p in
        let children, siblings =
          List.split_while ps ~f:(fun p' -> party_depth p' > depth)
        in
        { With_stack_hash.elt =
            { Tree.party = f p
            ; party_digest = ()
            ; calls = of_parties_list_map ~f ~party_depth children
            }
        ; stack_hash = ()
        }
        :: of_parties_list_map ~f ~party_depth siblings

  let of_parties_list ~party_depth parties =
    of_parties_list_map ~f:Fn.id ~party_depth parties

  let to_parties_list_map ~f (xs : _ t) =
    let rec collect depth (xs : _ t) acc =
      match xs with
      | [] ->
          acc
      | { elt = { party; calls; party_digest = _ }; stack_hash = _ } :: xs ->
          f ~depth party :: acc |> collect (depth + 1) calls |> collect depth xs
    in
    List.rev (collect 0 xs [])

  let to_parties_list xs =
    to_parties_list_map ~f:(fun ~depth:_ party -> party) xs

  let hd_party (xs : _ t) =
    match xs with
    | [] ->
        None
    | { elt = { party; calls = _; party_digest = _ }; stack_hash = _ } :: _ ->
        Some party

  let map = Tree.map_forest

  let mapi = Tree.mapi_forest

  let mapi_with_trees = Tree.mapi_forest_with_trees

  let%test_unit "Party_or_stack.of_parties_list" =
    let parties_list_1 = [ 0; 0; 0; 0 ] in
    let node i calls =
      { With_stack_hash.elt = { Tree.calls; party = i; party_digest = () }
      ; stack_hash = ()
      }
    in
    let parties_list_1_res : (int, unit, unit) t =
      let n0 = node 0 [] in
      [ n0; n0; n0; n0 ]
    in
    let f_index = mapi ~f:(fun i _p -> i) in
    [%test_eq: (int, unit, unit) t]
      (of_parties_list ~party_depth:Fn.id parties_list_1)
      parties_list_1_res ;
    let parties_list1_index : (int, unit, unit) t =
      let n i = node i [] in
      [ n 0; n 1; n 2; n 3 ]
    in
    [%test_eq: (int, unit, unit) t]
      (of_parties_list ~party_depth:Fn.id parties_list_1 |> f_index)
      parties_list1_index ;
    [%test_eq: int list]
      (to_parties_list (of_parties_list ~party_depth:Fn.id parties_list_1))
      parties_list_1 ;
    let parties_list_2 = [ 0; 0; 1; 1 ] in
    let parties_list_2_res = [ node 0 []; node 0 [ node 1 []; node 1 [] ] ] in
    let parties_list_2_index = [ node 0 []; node 1 [ node 2 []; node 3 [] ] ] in
    [%test_eq: (int, unit, unit) t]
      (of_parties_list ~party_depth:Fn.id parties_list_2)
      parties_list_2_res ;
    [%test_eq: (int, unit, unit) t]
      (of_parties_list ~party_depth:Fn.id parties_list_2 |> f_index)
      parties_list_2_index ;
    [%test_eq: int list]
      (to_parties_list (of_parties_list ~party_depth:Fn.id parties_list_2))
      parties_list_2 ;
    let parties_list_3 = [ 0; 0; 1; 0 ] in
    let parties_list_3_res = [ node 0 []; node 0 [ node 1 [] ]; node 0 [] ] in
    let parties_list_3_index = [ node 0 []; node 1 [ node 2 [] ]; node 3 [] ] in
    [%test_eq: (int, unit, unit) t]
      (of_parties_list ~party_depth:Fn.id parties_list_3)
      parties_list_3_res ;
    [%test_eq: (int, unit, unit) t]
      (of_parties_list ~party_depth:Fn.id parties_list_3 |> f_index)
      parties_list_3_index ;
    [%test_eq: int list]
      (to_parties_list (of_parties_list ~party_depth:Fn.id parties_list_3))
      parties_list_3 ;
    let parties_list_4 = [ 0; 1; 2; 3; 2; 1; 0 ] in
    let parties_list_4_res =
      [ node 0 [ node 1 [ node 2 [ node 3 [] ]; node 2 [] ]; node 1 [] ]
      ; node 0 []
      ]
    in
    let parties_list_4_index =
      [ node 0 [ node 1 [ node 2 [ node 3 [] ]; node 4 [] ]; node 5 [] ]
      ; node 6 []
      ]
    in
    [%test_eq: (int, unit, unit) t]
      (of_parties_list ~party_depth:Fn.id parties_list_4)
      parties_list_4_res ;
    [%test_eq: (int, unit, unit) t]
      (of_parties_list ~party_depth:Fn.id parties_list_4 |> f_index)
      parties_list_4_index ;
    [%test_eq: int list]
      (to_parties_list (of_parties_list ~party_depth:Fn.id parties_list_4))
      parties_list_4

  let to_parties_with_hashes_list (xs : _ t) =
    let rec collect (xs : _ t) acc =
      match xs with
      | [] ->
          acc
      | { elt = { party; calls; party_digest = _ }; stack_hash } :: xs ->
          (party, stack_hash) :: acc |> collect calls |> collect xs
    in
    List.rev (collect xs [])

  let hash_cons hash h_tl =
    Random_oracle.hash ~init:Hash_prefix_states.party_cons [| hash; h_tl |]

  let hash = function
    | [] ->
        Digest.Forest.empty
    | x :: _ ->
        With_stack_hash.stack_hash x

  let cons ?(calls = []) (party : Party.t) (xs : _ t) : _ t =
    let party_digest = Digest.Party.create party in
    let tree : _ Tree.t = { party; party_digest; calls } in
    { elt = tree
    ; stack_hash = Digest.Forest.cons (Digest.Tree.create tree) (hash xs)
    }
    :: xs

  let rec accumulate_hashes ~hash_party (xs : _ t) =
    let go = accumulate_hashes ~hash_party in
    match xs with
    | [] ->
        []
    | { elt = { party; calls; party_digest = _ }; stack_hash = _ } :: xs ->
        let calls = go calls in
        let xs = go xs in
        let node = { Tree.party; calls; party_digest = hash_party party } in
        let node_hash = Digest.Tree.create node in
        { elt = node; stack_hash = Digest.Forest.cons node_hash (hash xs) }
        :: xs

  let accumulate_hashes' (type a b) (xs : (Party.t, a, b) t) :
      (Party.t, Digest.Party.t, Digest.Forest.t) t =
    let hash_party (p : Party.t) = Digest.Party.create p in
    accumulate_hashes ~hash_party xs

  let accumulate_hashes_predicated xs =
    accumulate_hashes ~hash_party:Digest.Party.create xs

  (* Delegate_call means, preserve the current caller.
  *)
  let add_callers (type party party_with_caller party_digest digest id)
      (ps : (party, party_digest, digest) t)
      ~(call_type : party -> Party.Call_type.t)
      ~(add_caller : party -> id -> party_with_caller) ~(null_id : id)
      ~(party_id : party -> id) : (party_with_caller, party_digest, digest) t =
    let module Context = struct
      type t = { caller : id; self : id }
    end in
    let open Context in
    let rec go curr_context ps =
      match ps with
      | { With_stack_hash.elt = { Tree.party = p; party_digest; calls }
        ; stack_hash
        }
        :: ps ->
          let elt =
            let child_context =
              match call_type p with
              | Delegate_call ->
                  curr_context
              | Call ->
                  { caller = curr_context.self; self = party_id p }
            in
            let party_caller = child_context.caller in
            { Tree.party = add_caller p party_caller
            ; party_digest
            ; calls = go child_context calls
            }
          in
          { With_stack_hash.elt; stack_hash } :: go curr_context ps
      | [] ->
          []
    in
    go { self = null_id; caller = null_id } ps

  let add_callers' (type h1 h2) (ps : (Party.Wire.t, h1, h2) t) :
      (Party.t, h1, h2) t =
    add_callers ps
      ~call_type:(fun p -> p.body.caller)
      ~add_caller ~null_id:Token_id.default
      ~party_id:(fun p ->
        Account_id.(
          derive_token_id ~owner:(create p.body.public_key p.body.token_id)) )

  let add_callers_simple (type h1 h2) (ps : (Party.Simple.t, h1, h2) t) :
      (Party.t, h1, h2) t =
    add_callers ps
      ~call_type:(fun p -> p.body.caller)
      ~add_caller:add_caller_simple ~null_id:Token_id.default
      ~party_id:(fun p ->
        Account_id.(
          derive_token_id ~owner:(create p.body.public_key p.body.token_id)) )

  let remove_callers
      (type party_with_caller party_without_sender h1 h2 h1' h2' id)
      ~(map_party_digest : h1 -> h1') ~(map_stack_hash : h2 -> h2')
      (ps : (party_with_caller, h1, h2) t) ~(equal_id : id -> id -> bool)
      ~(add_call_type :
         party_with_caller -> Party.Call_type.t -> party_without_sender )
      ~(null_id : id) ~(party_caller : party_with_caller -> id) :
      (party_without_sender, h1', h2') t =
    let rec go ~top_level_party parent_caller ps =
      let call_type_for_party p : Party.Call_type.t =
        if top_level_party then Call
        else if equal_id parent_caller (party_caller p) then Delegate_call
        else Call
      in
      match ps with
      | { With_stack_hash.elt = { Tree.party = p; party_digest; calls }
        ; stack_hash
        }
        :: ps ->
          let ty = call_type_for_party p in
          { With_stack_hash.elt =
              { Tree.party = add_call_type p ty
              ; party_digest = map_party_digest party_digest
              ; calls = go ~top_level_party:false (party_caller p) calls
              }
          ; stack_hash = map_stack_hash stack_hash
          }
          :: go ~top_level_party parent_caller ps
      | [] ->
          []
    in
    go ~top_level_party:true null_id ps

  let%test_unit "add_callers and remove_callers" =
    let module P = struct
      type 'a t = { id : int; caller : 'a } [@@deriving compare, sexp]
    end in
    let module With_call_type = struct
      type tmp = (Party.Call_type.t P.t, unit, unit) t
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
      { Tree.party = { P.id; caller }
      ; party_digest = ()
      ; calls =
          List.map calls ~f:(fun elt ->
              { With_stack_hash.elt; stack_hash = () } )
      }
    in
    let t : With_call_type.t =
      let open Party.Call_type in
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
         ~party_id:(fun p -> p.id) )
      expected_output ;
    [%test_eq: With_call_type.t]
      (remove_callers expected_output ~equal_id:Int.equal
         ~map_party_digest:Fn.id ~map_stack_hash:Fn.id
         ~add_call_type:(fun p call_type -> { p with caller = call_type })
         ~null_id
         ~party_caller:(fun p -> p.caller) )
      t

  module With_hashes = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type 'data t =
          ( Party.Stable.V1.t * 'data
          , Digest.Party.Stable.V1.t
          , Digest.Forest.Stable.V1.t )
          Stable.V1.t
        [@@deriving sexp, compare, equal, hash, yojson]

        let to_latest = Fn.id
      end
    end]

    let empty = Digest.Forest.empty

    let hash_party ((p : Party.t), _) = Digest.Party.create p

    let accumulate_hashes xs : _ t = accumulate_hashes ~hash_party xs

    let of_parties_simple_list (xs : (Party.Simple.t * 'a) list) : _ t =
      of_parties_list xs ~party_depth:(fun ((p : Party.Simple.t), _) ->
          p.body.call_depth )
      |> add_callers
           ~call_type:(fun ((p : Party.Simple.t), _) -> p.body.caller)
           ~add_caller:(fun (p, x) id -> (add_caller_simple p id, x))
           ~null_id:Token_id.default
           ~party_id:(fun ((p : Party.Simple.t), _) ->
             Account_id.(
               derive_token_id ~owner:(create p.body.public_key p.body.token_id))
             )
      |> accumulate_hashes

    let of_parties_list (xs : (Party.Graphql_repr.t * 'a) list) : _ t =
      of_parties_list_map
        ~party_depth:(fun ((p : Party.Graphql_repr.t), _) -> p.body.call_depth)
        ~f:(fun (p, x) -> (Party.of_graphql_repr p, x))
        xs
      |> accumulate_hashes

    let to_parties_list (x : _ t) = to_parties_list x

    let to_parties_with_hashes_list (x : _ t) = to_parties_with_hashes_list x

    let other_parties_hash' xs = of_parties_list xs |> hash

    let other_parties_hash xs =
      List.map ~f:(fun x -> (x, ())) xs |> other_parties_hash'
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
        { fee_payer : Party.Fee_payer.Stable.V1.t
        ; other_parties : Party.Graphql_repr.Stable.V1.t list
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
        { fee_payer : Party.Fee_payer.Stable.V1.t
        ; other_parties : Party.Simple.Stable.V1.t list
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
    module V1 = struct
      type t =
        { fee_payer : Party.Fee_payer.Stable.V1.t
        ; other_parties :
            ( Party.Stable.V1.t
            , Digest.Party.Stable.V1.t
            , Digest.Forest.Stable.V1.t )
            Call_forest.Stable.V1.t
        ; memo : Signed_command_memo.Stable.V1.t
        }
      [@@deriving annot, sexp, compare, equal, hash, yojson, fields]

      let to_latest = Fn.id

      let version_byte = Base58_check.Version_bytes.zkapp_command

      let description = "Parties"

      module Wire = struct
        [%%versioned
        module Stable = struct
          module V1 = struct
            type t =
              { fee_payer : Party.Fee_payer.Stable.V1.t
              ; other_parties :
                  (Party.Wire.Stable.V1.t, unit, unit) Call_forest.Stable.V1.t
              ; memo : Signed_command_memo.Stable.V1.t
              }
            [@@deriving sexp, compare, equal, hash, yojson]

            let to_latest = Fn.id
          end
        end]

        let check (t : t) : unit =
          List.iter t.other_parties ~f:(fun p ->
              assert (Party.Call_type.equal p.elt.party.body.caller Call) )

        let of_graphql_repr (t : Graphql_repr.t) : t =
          { fee_payer = t.fee_payer
          ; memo = t.memo
          ; other_parties =
              Call_forest.of_parties_list_map t.other_parties
                ~f:Party.of_graphql_repr
                ~party_depth:(fun (p : Party.Graphql_repr.t) ->
                  p.body.call_depth )
              |> Call_forest.remove_callers ~equal_id:Token_id.equal
                   ~map_party_digest:ignore ~map_stack_hash:ignore
                   ~add_call_type:Party.to_wire ~null_id:Token_id.default
                   ~party_caller:(fun p -> p.body.caller)
          }

        let to_graphql_repr (t : t) : Graphql_repr.t =
          { fee_payer = t.fee_payer
          ; memo = t.memo
          ; other_parties =
              t.other_parties
              |> Call_forest.add_callers
                   ~call_type:(fun (p : Party.Wire.t) -> p.body.caller)
                   ~add_caller ~null_id:Token_id.default
                   ~party_id:(fun (p : Party.Wire.t) ->
                     Account_id.(
                       derive_token_id
                         ~owner:(create p.body.public_key p.body.token_id)) )
              |> Call_forest.to_parties_list_map ~f:(fun ~depth party ->
                     Party.to_graphql_repr party ~call_depth:depth )
          }

        let gen =
          let open Quickcheck.Generator in
          let open Let_syntax in
          let gen_call_forest =
            let%map xs =
              fixed_point (fun self ->
                  let%bind calls_length = small_non_negative_int in
                  list_with_length calls_length
                    (let%map party = Party.Wire.gen and calls = self in
                     { With_stack_hash.stack_hash = ()
                     ; elt =
                         { Call_forest.Tree.party; party_digest = (); calls }
                     } ) )
            in
            (* All top level parties should be "Call" not "Delegate_call" *)
            List.map xs
              ~f:
                (With_stack_hash.map
                   ~f:(fun (t : (Party.Wire.t, _, _) Call_forest.Tree.t) ->
                     { t with
                       party =
                         { t.party with
                           body = { t.party.body with caller = Call }
                         }
                     } ) )
          in
          let open Quickcheck.Let_syntax in
          let%map fee_payer = Party.Fee_payer.gen
          and other_parties = gen_call_forest
          and memo = Signed_command_memo.gen in
          { fee_payer; other_parties; memo }

        let shrinker : t Quickcheck.Shrinker.t =
          Quickcheck.Shrinker.create (fun t ->
              let shape = Call_forest.shape t.other_parties in
              Sequence.map
                (Quickcheck.Shrinker.shrink
                   Call_forest.Shape.quickcheck_shrinker shape )
                ~f:(fun shape' ->
                  { t with
                    other_parties = Call_forest.mask t.other_parties shape'
                  } ) )
      end

      let of_wire (w : Wire.t) : t =
        { fee_payer = w.fee_payer
        ; memo = w.memo
        ; other_parties =
            w.other_parties
            |> Call_forest.add_callers
                 ~call_type:(fun (p : Party.Wire.t) -> p.body.caller)
                 ~add_caller ~null_id:Token_id.default
                 ~party_id:(fun (p : Party.Wire.t) ->
                   Account_id.(
                     derive_token_id
                       ~owner:(create p.body.public_key p.body.token_id)) )
            |> Call_forest.accumulate_hashes ~hash_party:(fun (p : Party.t) ->
                   Digest.Party.create p )
        }

      let to_wire (t : t) : Wire.t =
        { fee_payer = t.fee_payer
        ; memo = t.memo
        ; other_parties =
            Call_forest.remove_callers ~equal_id:Token_id.equal
              ~map_party_digest:ignore ~map_stack_hash:ignore
              ~add_call_type:Party.to_wire ~null_id:Token_id.default
              ~party_caller:(fun p -> p.body.caller)
              t.other_parties
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
  ; other_parties =
      Call_forest.of_parties_list w.other_parties
        ~party_depth:(fun (p : Party.Simple.t) -> p.body.call_depth)
      |> Call_forest.add_callers
           ~call_type:(fun (p : Party.Simple.t) -> p.body.caller)
           ~add_caller:add_caller_simple ~null_id:Token_id.default
           ~party_id:(fun (p : Party.Simple.t) ->
             Account_id.(
               derive_token_id ~owner:(create p.body.public_key p.body.token_id))
             )
      |> Call_forest.accumulate_hashes ~hash_party:(fun (p : Party.t) ->
             Digest.Party.create p )
  }

let to_simple (t : t) : Simple.t =
  { fee_payer = t.fee_payer
  ; memo = t.memo
  ; other_parties =
      Call_forest.remove_callers ~equal_id:Token_id.equal
        ~map_party_digest:ignore ~map_stack_hash:ignore
        ~add_call_type:(fun { body = b; authorization } call_type ->
          { Party.Simple.authorization
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
              }
          } )
        ~null_id:Token_id.default
        ~party_caller:(fun (p : Party.t) -> p.body.caller)
        t.other_parties
      |> Call_forest.to_parties_list_map ~f:(fun ~depth (p : Party.Simple.t) ->
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

let parties (t : t) : _ Call_forest.t =
  let p = t.fee_payer in
  let body = Party.Body.of_fee_payer p.body in
  let fee_payer : Party.t =
    let p = t.fee_payer in
    { authorization = Control.Signature p.authorization; body }
  in
  Call_forest.cons fee_payer t.other_parties

let fee (t : t) : Currency.Fee.t = t.fee_payer.body.fee

let fee_payer_party ({ fee_payer; _ } : t) = fee_payer

let application_nonce (t : t) : Account.Nonce.t = (fee_payer_party t).body.nonce

let target_nonce (t : t) : Account.Nonce.t =
  let base_nonce = Account.Nonce.succ (application_nonce t) in
  let fee_payer_pubkey = t.fee_payer.body.public_key in
  let fee_payer_party_increments =
    List.count (Call_forest.to_list t.other_parties) ~f:(fun p ->
        Signature_lib.Public_key.Compressed.equal p.body.public_key
          fee_payer_pubkey
        && p.body.increment_nonce )
  in
  Account.Nonce.add base_nonce (Account.Nonce.of_int fee_payer_party_increments)

let fee_token (_t : t) = Token_id.default

let fee_payer (t : t) =
  Account_id.create t.fee_payer.body.public_key (fee_token t)

let other_parties_list (t : t) : Party.t list =
  Call_forest.fold t.other_parties ~init:[] ~f:(Fn.flip List.cons) |> List.rev

let parties_list (t : t) : Party.t list =
  Call_forest.fold t.other_parties
    ~init:[ Party.of_fee_payer (fee_payer_party t) ]
    ~f:(Fn.flip List.cons)
  |> List.rev

let fee_excess (t : t) =
  Fee_excess.of_single (fee_token t, Currency.Fee.Signed.of_unsigned (fee t))

let accounts_accessed (t : t) =
  Call_forest.fold t.other_parties
    ~init:[ fee_payer t ]
    ~f:(fun acc p -> Party.account_id p :: acc)
  |> List.rev |> List.stable_dedup

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

  module Parties = struct
    type t = Party.t list

    let if_ = value_if

    type party = Party.t

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
        { fee_payer : Party.Fee_payer.Stable.V1.t
        ; other_parties :
            ( Side_loaded_verification_key.Stable.V2.t
            , Zkapp_basic.F.Stable.V1.t )
            With_hash.Stable.V1.t
            option
            Call_forest.With_hashes.Stable.V1.t
        ; memo : Signed_command_memo.Stable.V1.t
        }
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end
  end]
end

let of_verifiable (t : Verifiable.t) : t =
  { fee_payer = t.fee_payer
  ; other_parties = Call_forest.map t.other_parties ~f:fst
  ; memo = t.memo
  }

module Transaction_commitment = struct
  module Stable = Kimchi_backend.Pasta.Basic.Fp.Stable

  type t = (Stable.Latest.t[@deriving sexp])

  let sexp_of_t = Stable.Latest.sexp_of_t

  let t_of_sexp = Stable.Latest.t_of_sexp

  let empty = Outside_hash_image.t

  let typ = Snark_params.Tick.Field.typ

  let create ~(other_parties_hash : Digest.Forest.t) : t =
    (other_parties_hash :> t)

  let create_complete (t : t) ~memo_hash ~(fee_payer_hash : Digest.Party.t) =
    Random_oracle.hash ~init:Hash_prefix.party_cons
      [| memo_hash; (fee_payer_hash :> t); t |]

  module Checked = struct
    type t = Pickles.Impls.Step.Field.t

    let create ~(other_parties_hash : Digest.Forest.Checked.t) =
      (other_parties_hash :> t)

    let create_complete (t : t) ~memo_hash
        ~(fee_payer_hash : Digest.Party.Checked.t) =
      Random_oracle.Checked.hash ~init:Hash_prefix.party_cons
        [| memo_hash; (fee_payer_hash :> t); t |]
  end
end

let other_parties_hash (t : t) = Call_forest.hash t.other_parties

let commitment (t : t) : Transaction_commitment.t =
  Transaction_commitment.create ~other_parties_hash:(other_parties_hash t)

(** This module defines weights for each component of a `Parties.t` element. *)
module Weight = struct
  let party : Party.t -> int = fun _ -> 1

  let fee_payer (_fp : Party.Fee_payer.t) : int = 1

  let other_parties : (Party.t, _, _) Call_forest.t -> int =
    Call_forest.fold ~init:0 ~f:(fun acc p -> acc + party p)

  let memo : Signed_command_memo.t -> int = fun _ -> 0
end

let weight (parties : t) : int =
  let { fee_payer; other_parties; memo } = parties in
  List.sum
    (module Int)
    ~f:Fn.id
    [ Weight.fee_payer fee_payer
    ; Weight.other_parties other_parties
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
        { parties : T.Stable.V1.t
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

module Valid : Valid_intf = struct
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
      type t =
        { parties : S.V1.t
        ; verification_keys :
            (Account_id.Stable.V2.t * Verification_key_hash.Stable.V1.t) list
        }
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  let create ~verification_keys parties : t = { parties; verification_keys }

  let of_verifiable (t : Verifiable.t) : t option =
    let open Option.Let_syntax in
    let tbl = Account_id.Table.create () in
    let%map () =
      Call_forest.fold t.other_parties ~init:(Some ())
        ~f:(fun acc (p, vk_opt) ->
          let%bind _ok = acc in
          let account_id = Party.account_id p in
          if Control.(Tag.equal Tag.Proof (Control.tag p.authorization)) then
            let%map { With_hash.hash; _ } = vk_opt in
            Account_id.Table.update tbl account_id ~f:(fun _ -> hash)
          else acc )
    in
    { parties = of_verifiable t
    ; verification_keys = Account_id.Table.to_alist tbl
    }

  let to_valid_unsafe (t : T.t) :
      [> `If_this_is_used_it_should_have_a_comment_justifying_it of t ] =
    `If_this_is_used_it_should_have_a_comment_justifying_it
      (create t ~verification_keys:[])

  let forget (t : t) : T.t = t.parties

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
      Call_forest.fold t.other_parties ~init:(Some ()) ~f:(fun acc p ->
          let%bind _ok = acc in
          let account_id = Party.account_id p in
          if Control.(Tag.equal Tag.Proof (Control.tag p.authorization)) then
            Option.map (find_vk account_id) ~f:(fun vk ->
                Account_id.Table.update tbl account_id ~f:(fun _ ->
                    With_hash.hash vk ) )
          else acc )
    in
    create ~verification_keys:(Account_id.Table.to_alist tbl) t
end

include Codable.Make_base58_check (Stable.Latest)

(* shadow the definitions from Make_base58_check *)
[%%define_locally Stable.Latest.(of_yojson, to_yojson)]

type other_parties = (Party.t, Digest.Party.t, Digest.Forest.t) Call_forest.t

let other_parties_deriver obj =
  let of_parties_with_depth (ps : Party.Graphql_repr.t list) : other_parties =
    Call_forest.of_parties_list ps
      ~party_depth:(fun (p : Party.Graphql_repr.t) -> p.body.call_depth)
    |> Call_forest.map ~f:Party.of_graphql_repr
    |> Call_forest.accumulate_hashes'
  and to_parties_with_depth (ps : other_parties) : Party.Graphql_repr.t list =
    ps
    |> Call_forest.to_parties_list_map ~f:(fun ~depth p ->
           Party.to_graphql_repr ~call_depth:depth p )
  in
  let open Fields_derivers_zkapps.Derivers in
  let inner = (list @@ Party.Graphql_repr.deriver @@ o ()) @@ o () in
  iso ~map:of_parties_with_depth ~contramap:to_parties_with_depth inner obj

let deriver obj =
  let open Fields_derivers_zkapps.Derivers in
  let ( !. ) = ( !. ) ~t_fields_annots in
  Fields.make_creator obj ~fee_payer:!.Party.Fee_payer.deriver
    ~other_parties:!.other_parties_deriver
    ~memo:!.Signed_command_memo.deriver
  |> finish "Parties" ~t_toplevel_annots

let arg_typ () = Fields_derivers_zkapps.(arg_typ (deriver @@ Derivers.o ()))

let typ () = Fields_derivers_zkapps.(typ (deriver @@ Derivers.o ()))

let to_json x = Fields_derivers_zkapps.(to_json (deriver @@ Derivers.o ())) x

let of_json x = Fields_derivers_zkapps.(of_json (deriver @@ Derivers.o ())) x

let other_parties_of_json x =
  Fields_derivers_zkapps.(
    of_json ((list @@ Party.Graphql_repr.deriver @@ o ()) @@ derivers ()))
    x

let parties_to_json x =
  Fields_derivers_zkapps.(to_json (deriver @@ derivers ())) x

let arg_query_string x =
  Fields_derivers_zkapps.Test.Loop.json_to_string_gql @@ to_json x

let dummy =
  let party : Party.t =
    { body = Party.Body.dummy; authorization = Control.dummy_of_tag Signature }
  in
  let fee_payer : Party.Fee_payer.t =
    { body = Party.Body.Fee_payer.dummy; authorization = Signature.dummy }
  in
  { fee_payer
  ; other_parties = Call_forest.cons party []
  ; memo = Signed_command_memo.empty
  }

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
  end )
