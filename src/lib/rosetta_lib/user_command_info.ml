open Core_kernel
module Fee_currency = Currency.Fee
module Amount_currency = Currency.Amount
open Rosetta_models
module Signed_command = Mina_base.Signed_command
module Token_id = Mina_base.Token_id
module Public_key = Signature_lib.Public_key
module Signed_command_memo = Mina_base.Signed_command_memo
module Payment_payload = Mina_base.Payment_payload
module Stake_delegation = Mina_base.Stake_delegation

let pk_to_public_key ~context (`Pk pk) =
  Public_key.Compressed.of_base58_check pk
  |> Result.map_error ~f:(fun _ ->
         Errors.create ~context `Public_key_format_not_valid )

let account_id (`Pk pk) (`Token_id token_id) =
  { Account_identifier.address = pk
  ; sub_account = None
  ; metadata = Some (Amount_of.Token_id.encode token_id)
  }

let token_id_of_account (account : Account_identifier.t) =
  let module Decoder = Amount_of.Token_id.T (Result) in
  Decoder.decode account.metadata
  |> Result.map ~f:(Option.value ~default:Amount_of.Token_id.default)
  |> Result.ok

module Op = struct
  type 'a t = { label : 'a; related_to : 'a option } [@@deriving equal]

  module T (M : Monad.S2) = struct
    let build ~a_eq ~plan ~f =
      let open M.Let_syntax in
      let%map _, rev_data =
        List.fold plan
          ~init:(M.return (0, []))
          ~f:(fun macc op ->
            let open M.Let_syntax in
            let%bind i, acc = macc in
            let operation_identifier i =
              { Operation_identifier.index = Int64.of_int_exn i
              ; network_index = None
              }
            in
            let related_operations =
              op.related_to
              |> Option.bind ~f:(fun relate ->
                     List.findi plan ~f:(fun _ a -> a_eq relate a.label) )
              |> Option.map ~f:(fun (i, _) -> [ operation_identifier i ])
              |> Option.value ~default:[]
            in
            let%map a =
              f ~related_operations
                ~operation_identifier:(operation_identifier i) op
            in
            (i + 1, a :: acc) )
      in
      List.rev rev_data
  end

  module Ident2 = struct
    type ('a, 'e) t = 'a

    module T = struct
      type ('a, 'e) t = 'a

      let map = `Define_using_bind

      let return a = a

      let bind a ~f = f a
    end

    include Monad.Make2 (T)
  end

  include T (Ident2)
end

module Kind = struct
  type t = [ `Payment | `Delegation ] [@@deriving yojson, equal, sexp, compare]
end

module Account_creation_fees_paid = struct
  type t =
    | By_no_one
    | By_fee_payer of Unsigned_extended.UInt64.t
    | By_receiver of Unsigned_extended.UInt64.t
  [@@deriving equal, to_yojson, sexp, compare]
end

module Failure_status = struct
  type t = [ `Applied of Account_creation_fees_paid.t | `Failed of string ]
  [@@deriving equal, to_yojson, sexp, compare]
end

type t =
  { kind : Kind.t
  ; fee_payer : [ `Pk of string ]
  ; source : [ `Pk of string ]
  ; receiver : [ `Pk of string ]
  ; fee_token : [ `Token_id of string ]
  ; token : [ `Token_id of string ]
  ; fee : Unsigned_extended.UInt64.t
  ; nonce : Unsigned_extended.UInt32.t
  ; amount : Unsigned_extended.UInt64.t option
  ; valid_until : Unsigned_extended.UInt32.t option
  ; memo : string option
  ; hash : string
  ; failure_status : Failure_status.t option
  }
[@@deriving to_yojson, equal, sexp, compare]

module Partial = struct
  type t =
    { kind : Kind.t
    ; fee_payer : [ `Pk of string ]
    ; source : [ `Pk of string ]
    ; receiver : [ `Pk of string ]
    ; fee_token : [ `Token_id of string ]
    ; token : [ `Token_id of string ]
    ; fee : Unsigned_extended.UInt64.t
    ; amount : Unsigned_extended.UInt64.t option
    ; valid_until : Unsigned_extended.UInt32.t option
    ; memo : string option
    }
  [@@deriving to_yojson, sexp, compare, equal]

  module Reason = Errors.Partial_reason

  let to_user_command_payload :
         t
      -> nonce:Unsigned_extended.UInt32.t
      -> (Signed_command.Payload.t, Errors.t) Result.t =
   fun t ~nonce ->
    let open Result.Let_syntax in
    let%bind fee_payer_pk = pk_to_public_key ~context:"Fee payer" t.fee_payer in
    let%bind source_pk = pk_to_public_key ~context:"Source" t.source in
    let%bind receiver_pk = pk_to_public_key ~context:"Receiver" t.receiver in
    let%bind () =
      Result.ok_if_true
        (Public_key.Compressed.equal fee_payer_pk source_pk)
        ~error:
          (Errors.create
             (`Operations_not_valid
               [ Errors.Partial_reason.Fee_payer_and_source_mismatch ] ) )
    in
    let%bind memo =
      match t.memo with
      | Some memo -> (
          try Ok (Signed_command_memo.create_from_string_exn memo)
          with _ -> Error (Errors.create `Memo_invalid) )
      | None ->
          Ok Signed_command_memo.empty
    in
    let%map body =
      match t.kind with
      | `Payment ->
          let%map amount =
            Result.of_option t.amount
              ~error:
                (Errors.create
                   (`Operations_not_valid
                     [ Errors.Partial_reason.Amount_not_some ] ) )
          in
          let payload =
            { Payment_payload.Poly.receiver_pk
            ; amount = Amount_currency.of_uint64 amount
            }
          in
          Signed_command.Payload.Body.Payment payload
      | `Delegation ->
          let payload =
            Stake_delegation.Set_delegate { new_delegate = receiver_pk }
          in
          Result.return @@ Signed_command.Payload.Body.Stake_delegation payload
    in
    Signed_command.Payload.create
      ~fee:(Fee_currency.of_uint64 t.fee)
      ~fee_payer_pk ~nonce ~body ~memo
      ~valid_until:
        (Option.map ~f:Mina_numbers.Global_slot_since_genesis.of_uint32
           t.valid_until )
end

let forget (t : t) : Partial.t =
  { kind = t.kind
  ; fee_payer = t.fee_payer
  ; source = t.source
  ; receiver = t.receiver
  ; fee_token = t.fee_token
  ; token = t.token
  ; fee = t.fee
  ; amount = t.amount
  ; valid_until = t.valid_until
  ; memo = t.memo
  }

let remember ~nonce ~hash t =
  { kind = t.kind
  ; fee_payer = t.fee_payer
  ; source = t.source
  ; receiver = t.receiver
  ; fee_token = t.fee_token
  ; token = t.token
  ; fee = t.fee
  ; amount = t.amount
  ; valid_until = t.valid_until
  ; memo = t.memo
  ; hash
  ; nonce
  ; failure_status = None
  }

let of_operations ?memo ?valid_until (ops : Operation.t list) :
    (Partial.t, Partial.Reason.t) Validation.t =
  (* TODO: If we care about DoS attacks, break early if length too large *)
  (* Note: It's better to have nice errors with the validation than micro-optimize searching through a small list a minimal number of times. *)
  let find_kind k (ops : Operation.t list) =
    let name = Operation_types.name k in
    List.find ops ~f:(fun op -> String.equal op.Operation._type name)
    |> Result.of_option ~error:[ Partial.Reason.Can't_find_kind name ]
  in
  let module V = Validation in
  let open V.Let_syntax in
  let open Partial.Reason in
  (* For a payment we demand:
     *
     * ops = length exactly 3
     *
     * payment_source_dec with account 'a, some amount 'x, status=None
     * fee_payment with account 'a, some amount 'y, status=None
     * payment_receiver_inc with account 'b, some amount 'x, status=None
  *)
  let payment =
    let%map () =
      if Mina_stdlib.List.Length.Compare.(ops = 3) then V.return ()
      else V.fail Length_mismatch
    and account_a =
      let open Result.Let_syntax in
      let%bind { account; _ } = find_kind `Payment_source_dec ops
      and { account = account'; _ } = find_kind `Fee_payment ops in
      match (account, account') with
      | Some x, Some y when Account_identifier.equal x y ->
          V.return x
      | Some _, Some _ ->
          V.fail Fee_payer_and_source_mismatch
      | None, _ | _, None ->
          V.fail Account_not_some
    and token =
      let open Result.Let_syntax in
      let%bind { account; _ } = find_kind `Payment_source_dec ops in
      match account with
      | Some account -> (
          match token_id_of_account account with
          | None ->
              V.fail Incorrect_token_id
          | Some token ->
              V.return (`Token_id token) )
      | None ->
          V.fail Account_not_some
    and fee_token =
      let open Result.Let_syntax in
      let%bind { account; _ } = find_kind `Fee_payment ops in
      match account with
      | Some account -> (
          match token_id_of_account account with
          | Some token_id ->
              V.return (`Token_id token_id)
          | None ->
              V.fail Incorrect_token_id )
      | None ->
          V.fail Account_not_some
    and account_b =
      let open Result.Let_syntax in
      let%bind { account; _ } = find_kind `Payment_receiver_inc ops in
      Result.of_option account ~error:[ Account_not_some ]
    and () =
      if
        List.for_all ops ~f:(fun op ->
            let p = Option.equal String.equal op.status in
            p None || p (Some "") )
      then V.return ()
      else V.fail Status_not_pending
    and payment_amount_x =
      let open Result.Let_syntax in
      let%bind { amount; _ } = find_kind `Payment_source_dec ops
      and { amount = amount'; _ } = find_kind `Payment_receiver_inc ops in
      match (amount, amount') with
      | Some x, Some y when Amount.equal (Amount_of.negated x) y ->
          V.return y
      | Some _, Some _ ->
          V.fail Amount_inc_dec_mismatch
      | None, _ | _, None ->
          V.fail Amount_not_some
    and payment_amount_y =
      let open Result.Let_syntax in
      let%bind { amount; _ } = find_kind `Fee_payment ops in
      match amount with
      | Some x when Amount_of.compare_to_int64 x 0L < 1 ->
          V.return (Amount_of.negated x)
      | Some _ ->
          V.fail Fee_not_negative
      | None ->
          V.fail Amount_not_some
    in
    { Partial.kind = `Payment
    ; fee_payer = `Pk account_a.address
    ; source = `Pk account_a.address
    ; receiver = `Pk account_b.address
    ; fee_token
    ; token (* TODO: Catch exception properly on these uint64 decodes *)
    ; fee = Unsigned.UInt64.of_string payment_amount_y.Amount.value
    ; amount = Some (Unsigned.UInt64.of_string payment_amount_x.Amount.value)
    ; valid_until
    ; memo
    }
  in
  (* For a delegation we demand:
     *
     * ops = length exactly 2
     *
     * fee_payment with account 'a, some amount 'y, status=None
     * delegate_change with account 'a, metadata:{delegate_change_target:'b}, status="Pending"
  *)
  let delegation =
    let%map () =
      if Mina_stdlib.List.Length.Compare.(ops = 2) then V.return ()
      else V.fail Length_mismatch
    and account_a =
      let open Result.Let_syntax in
      let%bind { account; _ } = find_kind `Fee_payment ops in
      Option.value_map account ~default:(V.fail Account_not_some) ~f:V.return
    and fee_token =
      let open Result.Let_syntax in
      let%bind { account; _ } = find_kind `Fee_payment ops in
      match account with
      | Some account -> (
          match token_id_of_account account with
          | Some token_id ->
              V.return (`Token_id token_id)
          | None ->
              V.fail Incorrect_token_id )
      | None ->
          V.fail Account_not_some
    and account_b =
      let open Result.Let_syntax in
      let%bind { metadata; _ } = find_kind `Delegate_change ops in
      match metadata with
      | Some metadata -> (
          match metadata with
          | `Assoc [ ("delegate_change_target", `String s) ] ->
              return s
          | _ ->
              V.fail Invalid_metadata )
      | None ->
          V.fail Account_not_some
    and () =
      if
        List.for_all ops ~f:(fun op ->
            let p = Option.equal String.equal op.status in
            p None || p (Some "") )
      then V.return ()
      else V.fail Status_not_pending
    and payment_amount_y =
      let open Result.Let_syntax in
      let%bind { amount; _ } = find_kind `Fee_payment ops in
      match amount with
      | Some x ->
          V.return (Amount_of.negated x)
      | None ->
          V.fail Amount_not_some
    in
    { Partial.kind = `Delegation
    ; fee_payer = `Pk account_a.address
    ; source = `Pk account_a.address
    ; receiver = `Pk account_b
    ; fee_token
    ; token =
        `Token_id Token_id.(default |> to_string)
        (* only default token can be delegated *)
    ; fee = Unsigned.UInt64.of_string payment_amount_y.Amount.value
    ; amount = None
    ; valid_until
    ; memo
    }
  in
  let partials = [ payment; delegation ] in
  let oks, errs = List.partition_map partials ~f:Result.to_either in
  match (oks, errs) with
  | [], errs ->
      (* no Oks *)
      Error (List.concat errs)
  | [ partial ], _ ->
      (* exactly one Ok *)
      Ok partial
  | _, _ ->
      (* more than one Ok, a bug in our implementation *)
      failwith
        "A sequence of operations must represent exactly one user command"

let to_operations ~failure_status (t : Partial.t) : Operation.t list =
  (* First build a plan. The plan specifies all operations ahead of time so
     * we can later compute indices and relations when we're building the full
     * models.
     *
     * For now, relations will be defined only on the two sides of a given
     * transfer. ie. Source decreases, and receiver increases.
  *)
  let plan : 'a Op.t list =
    ( if not Unsigned.UInt64.(equal t.fee zero) then
      [ { Op.label = `Fee_payment; related_to = None } ]
    else [] )
    @ ( match failure_status with
      | Some (`Applied (Account_creation_fees_paid.By_receiver amount)) ->
          [ { Op.label = `Account_creation_fee_via_payment amount
            ; related_to = None
            }
          ]
      | Some (`Applied (Account_creation_fees_paid.By_fee_payer amount)) ->
          [ { Op.label = `Account_creation_fee_via_fee_payer amount
            ; related_to = None
            }
          ]
      | _ ->
          [] )
    @
    match t.kind with
    | `Payment -> (
        (* When amount is not none, we move the amount from source to receiver -- unless it's a failure, we will capture that below *)
        match t.amount with
        | Some amount ->
            [ { Op.label = `Payment_source_dec amount; related_to = None }
            ; { Op.label = `Payment_receiver_inc amount
              ; related_to = Some (`Payment_source_dec amount)
              }
            ]
        | None ->
            [] )
    | `Delegation ->
        [ { Op.label = `Delegate_change; related_to = None } ]
  in
  Op.build
    ~a_eq:
      [%eq:
        [ `Fee_payment
        | `Payment_source_dec of Unsigned.UInt64.t
        | `Payment_receiver_inc of Unsigned.UInt64.t ]] ~plan
    ~f:(fun ~related_operations ~operation_identifier op ->
      let status, metadata, did_fail =
        match (op.label, failure_status) with
        (* If we're looking at mempool transactions, it's always pending *)
        | _, None ->
            (None, None, false)
        | _, Some (`Applied _) ->
            (Some `Success, None, false)
        | _, Some (`Failed reason) ->
            (Some `Failed, Some (`Assoc [ ("reason", `String reason) ]), true)
      in
      let pending_or_success_only = function
        | None ->
            None
        | Some (`Success | `Failed) ->
            Some `Success
      in
      let merge_metadata m1 m2 =
        match (m1, m2) with
        | None, None ->
            None
        | Some x, None | None, Some x ->
            Some x
        | Some (`Assoc xs), Some (`Assoc ys) ->
            Some (`Assoc (xs @ ys))
        | _ ->
            failwith "Unexpected pattern"
      in
      match op.label with
      | `Fee_payment ->
          { Operation.operation_identifier
          ; related_operations
          ; status =
              status |> pending_or_success_only
              |> Option.map ~f:Operation_statuses.name
          ; account = Some (account_id t.fee_payer t.fee_token)
          ; _type = Operation_types.name `Fee_payment
          ; amount = Some Amount_of.(negated @@ token t.fee_token t.fee)
          ; coin_change = None
          ; metadata
          }
      | `Payment_source_dec amount ->
          { Operation.operation_identifier
          ; related_operations
          ; status = Option.map ~f:Operation_statuses.name status
          ; account = Some (account_id t.source t.token)
          ; _type = Operation_types.name `Payment_source_dec
          ; amount =
              ( if did_fail then None
              else Some Amount_of.(negated @@ token t.token amount) )
          ; coin_change = None
          ; metadata
          }
      | `Payment_receiver_inc amount ->
          { Operation.operation_identifier
          ; related_operations
          ; status = Option.map ~f:Operation_statuses.name status
          ; account = Some (account_id t.receiver t.token)
          ; _type = Operation_types.name `Payment_receiver_inc
          ; amount =
              (if did_fail then None else Some (Amount_of.token t.token amount))
          ; coin_change = None
          ; metadata
          }
      | `Account_creation_fee_via_payment account_creation_fee ->
          { Operation.operation_identifier
          ; related_operations
          ; status = Option.map ~f:Operation_statuses.name status
          ; account = Some (account_id t.receiver t.token)
          ; _type = Operation_types.name `Account_creation_fee_via_payment
          ; amount = Some Amount_of.(negated @@ mina account_creation_fee)
          ; coin_change = None
          ; metadata
          }
      | `Account_creation_fee_via_fee_payer account_creation_fee ->
          { Operation.operation_identifier
          ; related_operations
          ; status = Option.map ~f:Operation_statuses.name status
          ; account = Some (account_id t.fee_payer t.fee_token)
          ; _type = Operation_types.name `Account_creation_fee_via_fee_payer
          ; amount = Some Amount_of.(negated @@ mina account_creation_fee)
          ; coin_change = None
          ; metadata
          }
      | `Delegate_change ->
          { Operation.operation_identifier
          ; related_operations
          ; status = Option.map ~f:Operation_statuses.name status
          ; account =
              Some (account_id t.source (`Token_id Amount_of.Token_id.default))
          ; _type = Operation_types.name `Delegate_change
          ; amount = None
          ; coin_change = None
          ; metadata =
              merge_metadata metadata
                (Some
                   (`Assoc
                     [ ( "delegate_change_target"
                       , `String
                           (let (`Pk r) = t.receiver in
                            r ) )
                     ] ) )
          } )

let to_operations' (t : t) : Operation.t list =
  to_operations ~failure_status:t.failure_status (forget t)

let%test_unit "payment_round_trip" =
  let start =
    { kind = `Payment (* default token *)
    ; fee_payer = `Pk "Alice"
    ; source = `Pk "Alice"
    ; token = `Token_id Amount_of.Token_id.default
    ; fee = Unsigned.UInt64.of_int 2_000_000_000
    ; receiver = `Pk "Bob"
    ; fee_token = `Token_id Amount_of.Token_id.default
    ; nonce = Unsigned.UInt32.of_int 3
    ; amount = Some (Unsigned.UInt64.of_int 2_000_000_000)
    ; failure_status = None
    ; hash = "TXN_1_HASH"
    ; valid_until = Some (Unsigned.UInt32.of_int 10_000)
    ; memo = Some "hello"
    }
  in
  let ops = to_operations' start in
  match of_operations ?valid_until:start.valid_until ?memo:start.memo ops with
  | Ok partial ->
      [%test_eq: Partial.t] partial (forget start)
  | Error e ->
      failwithf !"Mismatch because %{sexp: Partial.Reason.t list}" e ()

let%test_unit "delegation_round_trip" =
  let start =
    { kind = `Delegation
    ; fee_payer = `Pk "Alice"
    ; source = `Pk "Alice"
    ; token = `Token_id Amount_of.Token_id.default
    ; fee = Unsigned.UInt64.of_int 1_000_000_000
    ; receiver = `Pk "Bob"
    ; fee_token = `Token_id Amount_of.Token_id.default
    ; nonce = Unsigned.UInt32.of_int 42
    ; amount = None
    ; failure_status = None
    ; hash = "TXN_2_HASH"
    ; valid_until = Some (Unsigned.UInt32.of_int 867888)
    ; memo = Some "hello"
    }
  in
  let ops = to_operations' start in
  match of_operations ops ?valid_until:start.valid_until ?memo:start.memo with
  | Ok partial ->
      [%test_eq: Partial.t] partial (forget start)
  | Error e ->
      failwithf !"Mismatch because %{sexp: Partial.Reason.t list}" e ()

let non_default_token =
  `Token_id
    (Token_id.to_string (Quickcheck.random_value Token_id.gen_non_default))

let dummies =
  [ { kind = `Payment (* default token *)
    ; fee_payer = `Pk "Alice"
    ; source = `Pk "Alice"
    ; token = `Token_id Amount_of.Token_id.default
    ; fee_token = `Token_id Amount_of.Token_id.default
    ; fee = Unsigned.UInt64.of_int 2_000_000_000
    ; receiver = `Pk "Bob"
    ; nonce = Unsigned.UInt32.of_int 3
    ; amount = Some (Unsigned.UInt64.of_int 2_000_000_000)
    ; failure_status = Some (`Applied Account_creation_fees_paid.By_no_one)
    ; hash = "TXN_1_HASH"
    ; valid_until = None
    ; memo = Some "hello"
    }
  ; { kind = `Payment (* new account created *)
    ; fee_payer = `Pk "Alice"
    ; source = `Pk "Alice"
    ; token = `Token_id Amount_of.Token_id.default
    ; fee_token = `Token_id Amount_of.Token_id.default
    ; fee = Unsigned.UInt64.of_int 2_000_000_000
    ; receiver = `Pk "Bob"
    ; nonce = Unsigned.UInt32.of_int 3
    ; amount = Some (Unsigned.UInt64.of_int 2_000_000_000)
    ; failure_status =
        Some
          (`Applied
            (Account_creation_fees_paid.By_receiver
               (Unsigned.UInt64.of_int 1_000_000) ) )
    ; hash = "TXN_1new_HASH"
    ; valid_until = None
    ; memo = Some "hello"
    }
  ; { kind = `Payment (* failed payment *)
    ; fee_payer = `Pk "Alice"
    ; source = `Pk "Alice"
    ; token = `Token_id Amount_of.Token_id.default
    ; fee_token = `Token_id Amount_of.Token_id.default
    ; fee = Unsigned.UInt64.of_int 2_000_000_000
    ; receiver = `Pk "Bob"
    ; nonce = Unsigned.UInt32.of_int 3
    ; amount = Some (Unsigned.UInt64.of_int 2_000_000_000)
    ; failure_status = Some (`Failed "Failure")
    ; hash = "TXN_1fail_HASH"
    ; valid_until = None
    ; memo = Some "hello"
    }
  ; { kind = `Payment (* custom token *)
    ; fee_payer = `Pk "Alice"
    ; source = `Pk "Alice"
    ; token = non_default_token
    ; fee = Unsigned.UInt64.of_int 2_000_000_000
    ; receiver = `Pk "Bob"
    ; fee_token = `Token_id Amount_of.Token_id.default
    ; nonce = Unsigned.UInt32.of_int 3
    ; amount = Some (Unsigned.UInt64.of_int 2_000_000_000)
    ; failure_status = Some (`Applied Account_creation_fees_paid.By_no_one)
    ; hash = "TXN_1a_HASH"
    ; valid_until = None
    ; memo = Some "hello"
    }
  ; { kind = `Payment (* custom fee-token *)
    ; fee_payer = `Pk "Alice"
    ; source = `Pk "Alice"
    ; token = `Token_id Amount_of.Token_id.default
    ; fee = Unsigned.UInt64.of_int 2_000_000_000
    ; receiver = `Pk "Bob"
    ; fee_token = non_default_token
    ; nonce = Unsigned.UInt32.of_int 3
    ; amount = Some (Unsigned.UInt64.of_int 2_000_000_000)
    ; failure_status = Some (`Applied Account_creation_fees_paid.By_no_one)
    ; hash = "TXN_1b_HASH"
    ; valid_until = None
    ; memo = Some "hello"
    }
  ; { kind = `Delegation
    ; fee_payer = `Pk "Alice"
    ; source = `Pk "Alice"
    ; token = `Token_id Amount_of.Token_id.default
    ; fee_token = `Token_id Amount_of.Token_id.default
    ; fee = Unsigned.UInt64.of_int 2_000_000_000
    ; receiver = `Pk "Bob"
    ; nonce = Unsigned.UInt32.of_int 3
    ; amount = None
    ; failure_status = Some (`Applied Account_creation_fees_paid.By_no_one)
    ; hash = "TXN_2_HASH"
    ; valid_until = None
    ; memo = Some "hello"
    }
  ]
