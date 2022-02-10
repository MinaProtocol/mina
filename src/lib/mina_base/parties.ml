open Core
module Digest = Kimchi_backend.Pasta.Basic.Fp

module Party_or_stack = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('party, 'digest) t =
        | Party of 'party * 'digest
        | Stack of (('party, 'digest) t list * 'digest)
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  let of_parties_list ~party_depth parties =
    let _depth, stack =
      List.fold ~init:(-1, []) parties ~f:(fun (depth, stack) party ->
          let new_depth = party_depth party in
          let depth, stack =
            if depth = -1 then
              (new_depth - 1, List.init new_depth ~f:(Fn.const []))
            else (depth, stack)
          in
          if depth + 1 = new_depth then
            (new_depth, [ Party (party, ()) ] :: stack)
          else
            let rec go depth stack =
              match stack with
              | xs :: stack when depth = new_depth ->
                  (* We're at the correct depth, insert this party. *)
                  (depth, (Party (party, ()) :: xs) :: stack)
              | xs :: ys :: stack ->
                  (* We're still too deep, finalize the current parties and
                     push them inside the parent parties.
                  *)
                  go (depth - 1) ((Stack (List.rev xs, ()) :: ys) :: stack)
              | _ ->
                  (* An invariant is broken. The depth doesn't correspond
                     with any of the depths remaining in the stack. In
                     practise, this means that [0 <= new_depth <= depth]
                     wasn't true.
                  *)
                  assert false
            in
            go depth stack)
    in
    let rec finalize stack =
      match stack with
      | [] ->
          (* Empty stack *)
          []
      | [ xs ] ->
          (* Final stack is promoted to be the actual stack. *)
          List.rev xs
      | xs :: ys :: stack ->
          (* Finalize the current parties and push them inside the parent
             parties.
          *)
          finalize ((Stack (List.rev xs, ()) :: ys) :: stack)
    in
    finalize stack

  let to_parties_list (xs : _ t list) =
    let rec collect acc (xs : _ t list) =
      match xs with
      | [] ->
          acc
      | Party (party, _) :: xs ->
          collect (party :: acc) xs
      | Stack (xs, _) :: xss ->
          let acc = collect acc xs in
          collect acc xss
    in
    List.rev (collect [] xs)

  let%test_unit "Party_or_stack.of_parties_list" =
    let parties_list_1 = [ 0; 0; 0; 0 ] in
    let parties_list_1_res =
      [ Party (0, ()); Party (0, ()); Party (0, ()); Party (0, ()) ]
    in
    [%test_eq: (int, unit) t list]
      (of_parties_list ~party_depth:Fn.id parties_list_1)
      parties_list_1_res ;
    [%test_eq: int list]
      (to_parties_list (of_parties_list ~party_depth:Fn.id parties_list_1))
      parties_list_1 ;
    let parties_list_2 = [ 0; 0; 1; 1 ] in
    let parties_list_2_res =
      [ Party (0, ())
      ; Party (0, ())
      ; Stack ([ Party (1, ()); Party (1, ()) ], ())
      ]
    in
    [%test_eq: (int, unit) t list]
      (of_parties_list ~party_depth:Fn.id parties_list_2)
      parties_list_2_res ;
    [%test_eq: int list]
      (to_parties_list (of_parties_list ~party_depth:Fn.id parties_list_2))
      parties_list_2 ;
    let parties_list_3 = [ 0; 0; 1; 0 ] in
    let parties_list_3_res =
      [ Party (0, ())
      ; Party (0, ())
      ; Stack ([ Party (1, ()) ], ())
      ; Party (0, ())
      ]
    in
    [%test_eq: (int, unit) t list]
      (of_parties_list ~party_depth:Fn.id parties_list_3)
      parties_list_3_res ;
    [%test_eq: int list]
      (to_parties_list (of_parties_list ~party_depth:Fn.id parties_list_3))
      parties_list_3 ;
    let parties_list_4 = [ 0; 1; 2; 3; 2; 1; 0 ] in
    let parties_list_4_res =
      [ Party (0, ())
      ; Stack
          ( [ Party (1, ())
            ; Stack
                ( [ Party (2, ()); Stack ([ Party (3, ()) ], ()); Party (2, ()) ]
                , () )
            ; Party (1, ())
            ]
          , () )
      ; Party (0, ())
      ]
    in
    [%test_eq: (int, unit) t list]
      (of_parties_list ~party_depth:Fn.id parties_list_4)
      parties_list_4_res ;
    [%test_eq: int list]
      (to_parties_list (of_parties_list ~party_depth:Fn.id parties_list_4))
      parties_list_4

  let to_parties_with_hashes_list (xs : _ t list) =
    let rec collect acc (xs : _ t list) =
      match xs with
      | [] ->
          acc
      | Party (party, hash) :: xs ->
          collect ((party, hash) :: acc) xs
      | Stack (xs, _) :: xss ->
          let acc = collect acc xs in
          collect acc xss
    in
    List.rev (collect [] xs)

  let empty = Outside_hash_image.t

  let hash_cons hash h_tl =
    Random_oracle.hash ~init:Hash_prefix_states.party_cons [| hash; h_tl |]

  let hash ~hash_party = function
    | Party (party, _) ->
        hash_party party
    | Stack (_, hash) ->
        hash

  let stack_hash = function
    | [] ->
        empty
    | (Party (_, hash) | Stack (_, hash)) :: _ ->
        hash

  let rec map (x : _ t) ~f =
    match x with
    | Party (party, h) ->
        Party (f party, h)
    | Stack (stack, h) ->
        Stack (map_stack ~f stack, h)

  and map_stack (xs : _ t list) ~f = List.map ~f:(map ~f) xs

  let rec accumulate_hashes ~hash_party (xs : _ t list) =
    let go = accumulate_hashes ~hash_party in
    match xs with
    | [] ->
        []
    | Party (party, _) :: xs ->
        let tl = go xs in
        Party (party, hash_cons (hash_party party) (stack_hash tl)) :: tl
    | Stack (stack, _) :: xs ->
        let tl = go xs in
        let hd_stack = go stack in
        Stack (hd_stack, hash_cons (stack_hash hd_stack) (stack_hash tl)) :: tl

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
          (Party.Stable.V1.t * 'data, Digest.Stable.V1.t) Stable.V1.t list
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

    let hash x = hash ~hash_party x

    let stack_hash = stack_hash

    let other_parties_hash' xs = of_parties_list xs |> stack_hash

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
            Party_or_stack.With_hashes.Stable.V1.t
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
      List.map ~f:fst (Party_or_stack.to_parties_list t.other_parties)
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
      (Party_or_stack.With_hashes.other_parties_hash t.other_parties)
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
  let memo obj' =
    Signed_command_memo.(iso_string obj' ~name:"Memo" ~to_string ~of_string)
  in
  Fields.make_creator obj ~fee_payer:!.Party.Fee_payer.deriver
    ~other_parties:!.(list @@ Party.deriver @@ o ())
    ~memo:!.memo
  |> finish ~name:"SendSnappInput"

let%test_unit "json roundtrip dummy" =
  let party : Party.t =
    { data = { body = Party.Body.dummy; predicate = Party.Predicate.Accept }
    ; authorization = Control.dummy_of_tag Signature
    }
  in
  let fee_payer : Party.Fee_payer.t =
    { data = Party.Predicated.Fee_payer.dummy; authorization = Signature.dummy }
  in
  let dummy : t =
    { fee_payer; other_parties = [ party ]; memo = Signed_command_memo.empty }
  in
  let module Fd = Fields_derivers_snapps.Derivers in
  let full = deriver @@ Fd.o () in
  [%test_eq: t] dummy (dummy |> Fd.to_json full |> Fd.of_json full)
