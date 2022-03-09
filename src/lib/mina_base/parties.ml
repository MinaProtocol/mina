open Core_kernel
module Digest = Kimchi_backend.Pasta.Basic.Fp

module Call_forest = struct
  let empty = Outside_hash_image.t

  module Tree = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('party, 'digest) t =
          { party : 'party
          ; party_digest : 'digest
          ; calls :
              (('party, 'digest) t, 'digest) With_stack_hash.Stable.V1.t list
          }
        [@@deriving sexp, compare, equal, hash, yojson]

        let to_latest = Fn.id
      end
    end]

    let rec map (t : _ t) ~f =
      { calls = List.map t.calls ~f:(With_stack_hash.map ~f:(map ~f))
      ; party = f t.party
      ; party_digest = t.party_digest
      }

    let hash { party = _; calls; party_digest } =
      Random_oracle.hash ~init:Hash_prefix_states.party_node
        [| party_digest
         ; (match calls with [] -> empty | e :: _ -> e.stack_hash)
        |]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('party, 'digest) t =
        ( ('party, 'digest) Tree.Stable.V1.t
        , 'digest )
        With_stack_hash.Stable.V1.t
        list
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  let rec of_parties_list ~(party_depth : 'p -> int) (parties : 'p list) :
      ('p, unit) t =
    match parties with
    | [] ->
        []
    | p :: ps ->
        let depth = party_depth p in
        let children, siblings =
          List.split_while ps ~f:(fun p' -> party_depth p' > depth)
        in
        { With_stack_hash.elt =
            { Tree.party = p
            ; party_digest = ()
            ; calls = of_parties_list ~party_depth children
            }
        ; stack_hash = ()
        }
        :: of_parties_list ~party_depth siblings

  let to_parties_list (xs : _ t) =
    let rec collect (xs : _ t) acc =
      match xs with
      | [] ->
          acc
      | { elt = { party; calls; party_digest = _ }; stack_hash = _ } :: xs ->
          party :: acc |> collect calls |> collect xs
    in
    List.rev (collect xs [])

  let%test_unit "Party_or_stack.of_parties_list" =
    let parties_list_1 = [ 0; 0; 0; 0 ] in
    let node i calls =
      { With_stack_hash.elt = { Tree.calls; party = i; party_digest = () }
      ; stack_hash = ()
      }
    in
    let parties_list_1_res : (int, unit) t =
      let n0 = node 0 [] in
      [ n0; n0; n0; n0 ]
    in
    [%test_eq: (int, unit) t]
      (of_parties_list ~party_depth:Fn.id parties_list_1)
      parties_list_1_res ;
    [%test_eq: int list]
      (to_parties_list (of_parties_list ~party_depth:Fn.id parties_list_1))
      parties_list_1 ;
    let parties_list_2 = [ 0; 0; 1; 1 ] in
    let parties_list_2_res = [ node 0 []; node 0 [ node 1 []; node 1 [] ] ] in
    [%test_eq: (int, unit) t]
      (of_parties_list ~party_depth:Fn.id parties_list_2)
      parties_list_2_res ;
    [%test_eq: int list]
      (to_parties_list (of_parties_list ~party_depth:Fn.id parties_list_2))
      parties_list_2 ;
    let parties_list_3 = [ 0; 0; 1; 0 ] in
    let parties_list_3_res = [ node 0 []; node 0 [ node 1 [] ]; node 0 [] ] in
    [%test_eq: (int, unit) t]
      (of_parties_list ~party_depth:Fn.id parties_list_3)
      parties_list_3_res ;
    [%test_eq: int list]
      (to_parties_list (of_parties_list ~party_depth:Fn.id parties_list_3))
      parties_list_3 ;
    let parties_list_4 = [ 0; 1; 2; 3; 2; 1; 0 ] in
    let parties_list_4_res =
      [ node 0 [ node 1 [ node 2 [ node 3 [] ]; node 2 [] ]; node 1 [] ]
      ; node 0 []
      ]
    in
    [%test_eq: (int, unit) t]
      (of_parties_list ~party_depth:Fn.id parties_list_4)
      parties_list_4_res ;
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

  let hash = function [] -> empty | x :: _ -> With_stack_hash.stack_hash x

  let map (x : _ t) ~f = List.map x ~f:(With_stack_hash.map ~f:(Tree.map ~f))

  let rec accumulate_hashes ~hash_party (xs : _ t) =
    let go = accumulate_hashes ~hash_party in
    match xs with
    | [] ->
        []
    | { elt = { party; calls; party_digest = _ }; stack_hash = _ } :: xs ->
        let calls = go calls in
        let xs = go xs in
        let node = { Tree.party; calls; party_digest = hash_party party } in
        let node_hash = Tree.hash node in
        { elt = node; stack_hash = hash_cons node_hash (hash xs) } :: xs

  let accumulate_hashes' xs =
    let hash_party (p : Party.t) = Party.Predicated.digest p.data in
    accumulate_hashes ~hash_party xs

  let accumulate_hashes_predicated xs =
    accumulate_hashes ~hash_party:Party.Predicated.digest xs

  module With_hashes = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type 'data t =
          (Party.Stable.V1.t * 'data, Digest.Stable.V1.t) Stable.V1.t
        [@@deriving sexp, compare, equal, hash, yojson]

        let to_latest = Fn.id
      end
    end]

    let empty = empty

    let hash_party ((p : Party.t), _) = Party.Predicated.digest p.data

    let accumulate_hashes xs : _ t = accumulate_hashes ~hash_party xs

    let of_parties_list xs : _ t =
      of_parties_list
        ~party_depth:(fun ((p : Party.t), _) -> p.data.body.call_depth)
        xs
      |> accumulate_hashes

    let to_parties_list (x : _ t) = to_parties_list x

    let to_parties_with_hashes_list (x : _ t) = to_parties_with_hashes_list x

    let other_parties_hash' xs = of_parties_list xs |> hash

    let other_parties_hash xs =
      List.map ~f:(fun x -> (x, ())) xs |> other_parties_hash'
  end
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      { fee_payer : Party.Fee_payer.Stable.V1.t
      ; other_parties : Party.Stable.V1.t list
      ; memo : Signed_command_memo.Stable.V1.t
      }
    [@@deriving sexp, compare, equal, hash, yojson, fields]

    let to_latest = Fn.id

    let version_byte = Base58_check.Version_bytes.snapp_command

    let description = "Parties"
  end
end]

include Codable.Make_base58_check (Stable.Latest)

(* shadow the definitions from Make_base58_check *)
[%%define_locally Stable.Latest.(of_yojson, to_yojson)]

module Valid = struct
  module Stable = Stable

  type t = Stable.Latest.t
end

let check_depths (t : t) =
  try
    assert (t.fee_payer.data.body.call_depth = 0) ;
    let (_ : int) =
      List.fold ~init:0 t.other_parties ~f:(fun depth party ->
          let new_depth = party.data.body.call_depth in
          if new_depth >= 0 && new_depth <= depth + 1 then new_depth
          else assert false)
    in
    true
  with _ -> false

let check (t : t) : bool = check_depths t

let parties (t : t) : Party.t list =
  let p = t.fee_payer in
  let body = Party.Body.of_fee_payer p.data.body in
  { authorization = Control.Signature p.authorization
  ; data = { body; predicate = Party.Predicate.Nonce p.data.predicate }
  }
  :: t.other_parties

let fee (t : t) : Currency.Fee.t = t.fee_payer.data.body.balance_change

let fee_payer_party ({ fee_payer; _ } : t) = fee_payer

let fee_payer (t : t) = Party.Fee_payer.account_id (fee_payer_party t)

let nonce (t : t) : Account.Nonce.t = (fee_payer_party t).data.predicate

let fee_token (_t : t) = Token_id.default

let fee_excess (t : t) =
  Fee_excess.of_single (fee_token t, Currency.Fee.Signed.of_unsigned (fee t))

let accounts_accessed (t : t) =
  List.map (parties t) ~f:(fun p ->
      Account_id.create p.data.body.public_key p.data.body.token_id)
  |> List.stable_dedup

let fee_payer_pk (t : t) = t.fee_payer.data.body.public_key

let value_if b ~then_ ~else_ = if b then then_ else else_

module Virtual = struct
  module First_party = Party

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
            Pickles.Side_loaded.Verification_key.Stable.V2.t option
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
  ; other_parties =
      List.map ~f:fst (Call_forest.to_parties_list t.other_parties)
  ; memo = t.memo
  }

module Transaction_commitment = struct
  module Stable = Kimchi_backend.Pasta.Basic.Fp.Stable

  type t = (Stable.Latest.t[@deriving sexp])

  let sexp_of_t = Stable.Latest.sexp_of_t

  let t_of_sexp = Stable.Latest.t_of_sexp

  let empty = Outside_hash_image.t

  let typ = Snark_params.Tick.Field.typ

  let create ~other_parties_hash ~protocol_state_predicate_hash ~memo_hash : t =
    Random_oracle.hash ~init:Hash_prefix.party_with_protocol_state_predicate
      [| protocol_state_predicate_hash; other_parties_hash; memo_hash |]

  let with_fee_payer (t : t) ~fee_payer_hash =
    Random_oracle.hash ~init:Hash_prefix.party_cons [| fee_payer_hash; t |]

  module Checked = struct
    type t = Pickles.Impls.Step.Field.t

    let create ~other_parties_hash ~protocol_state_predicate_hash ~memo_hash =
      Random_oracle.Checked.hash
        ~init:Hash_prefix.party_with_protocol_state_predicate
        [| protocol_state_predicate_hash; other_parties_hash; memo_hash |]

    let with_fee_payer (t : t) ~fee_payer_hash =
      Random_oracle.Checked.hash ~init:Hash_prefix.party_cons
        [| fee_payer_hash; t |]
  end
end

let commitment (t : t) : Transaction_commitment.t =
  Transaction_commitment.create
    ~other_parties_hash:
      (Call_forest.With_hashes.other_parties_hash t.other_parties)
    ~protocol_state_predicate_hash:
      (Snapp_predicate.Protocol_state.digest
         t.fee_payer.data.body.protocol_state)
    ~memo_hash:(Signed_command_memo.hash t.memo)

(** This module defines weights for each component of a `Parties.t` element. *)
module Weight = struct
  let party : Party.t -> int = fun _ -> 1

  let fee_payer (fp : Party.Fee_payer.t) : int = Party.of_fee_payer fp |> party

  let other_parties : Party.t list -> int = List.sum (module Int) ~f:party

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

let deriver obj =
  let open Fields_derivers_snapps.Derivers in
  Fields.make_creator obj ~fee_payer:!.Party.Fee_payer.deriver
    ~other_parties:!.(list @@ Party.deriver @@ o ())
    ~memo:!.Signed_command_memo.deriver
  |> finish ~name:"Parties"

let arg_typ () = Fields_derivers_snapps.(arg_typ (deriver @@ Derivers.o ()))

let typ () = Fields_derivers_snapps.(typ (deriver @@ Derivers.o ()))

let to_json x = Fields_derivers_snapps.(to_json (deriver @@ Derivers.o ())) x

let of_json x = Fields_derivers_snapps.(of_json (deriver @@ Derivers.o ())) x

let arg_query_string x =
  Fields_derivers_snapps.Test.Loop.json_to_string_gql @@ to_json x

let dummy =
  let party : Party.t =
    { data = { body = Party.Body.dummy; predicate = Party.Predicate.Accept }
    ; authorization = Control.dummy_of_tag Signature
    }
  in
  let fee_payer : Party.Fee_payer.t =
    { data = Party.Predicated.Fee_payer.dummy; authorization = Signature.dummy }
  in
  { fee_payer; other_parties = [ party ]; memo = Signed_command_memo.empty }

let inner_query =
  lazy
    (Option.value_exn ~message:"Invariant: All projectable derivers are Some"
       Fields_derivers_snapps.(inner_query (deriver @@ Derivers.o ())))

let%test_module "Test" =
  ( module struct
    module Fd = Fields_derivers_snapps.Derivers

    let full = deriver @@ Fd.o ()

    let%test_unit "json roundtrip dummy" =
      [%test_eq: t] dummy (dummy |> Fd.to_json full |> Fd.of_json full)

    let%test_unit "full circuit" =
      Run_in_thread.block_on_async_exn
      @@ fun () -> Fields_derivers_snapps.Test.Loop.run full dummy
  end )
