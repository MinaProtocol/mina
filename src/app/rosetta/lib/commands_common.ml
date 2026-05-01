open Core_kernel
open Rosetta_lib
open Rosetta_models

let account_id = User_command_info.account_id

module Op = User_command_info.Op

module Internal_command_info = struct
  module Kind = struct
    type t = [ `Coinbase | `Fee_transfer | `Fee_transfer_via_coinbase ]
    [@@deriving equal, to_yojson]

    let to_string (t : t) =
      match t with
      | `Coinbase ->
          "coinbase"
      | `Fee_transfer ->
          "fee_transfer"
      | `Fee_transfer_via_coinbase ->
          "fee_transfer_via_coinbase"
  end

  type t =
    { kind : Kind.t
    ; receiver : [ `Pk of string ]
    ; receiver_account_creation_fee_paid : Unsigned_extended.UInt64.t option
    ; fee : Unsigned_extended.UInt64.t
    ; token : [ `Token_id of string ]
    ; sequence_no : int
    ; secondary_sequence_no : int
    ; hash : string
    ; coinbase_receiver : [ `Pk of string ] option
    }
  [@@deriving to_yojson]

  module T (M : Monad_fail.S) = struct
    module Op_build = Op.T (M)

    let to_operations (t : t) : (Operation.t list, Errors.t) M.t =
      (* We choose to represent the dec-side of fee transfers from txns from the
       * canonical user command that created them so we are able consistently
       * produce more balance changing operations in the mempool or a block.
       * *)
      let plan : 'a Op.t list =
        let mk_account_creation_fee related =
          match t.receiver_account_creation_fee_paid with
          | None ->
              []
          | Some fee ->
              [ { Op.label = `Account_creation_fee_via_fee_receiver fee
                ; related_to = Some related
                }
              ]
        in
        match t.kind with
        | `Coinbase ->
            (* The coinbase transaction is really incrementing by the coinbase
               * amount *)
            [ { Op.label = `Coinbase_inc; related_to = None } ]
            @ mk_account_creation_fee `Coinbase_inc
        | `Fee_transfer ->
            [ { Op.label = `Fee_receiver_inc; related_to = None } ]
            @ mk_account_creation_fee `Fee_receiver_inc
        | `Fee_transfer_via_coinbase ->
            [ { Op.label = `Fee_receiver_inc; related_to = None }
            ; { Op.label = `Fee_payer_dec; related_to = Some `Fee_receiver_inc }
            ]
            @ mk_account_creation_fee `Fee_receiver_inc
      in
      Op_build.build
        ~a_eq:
          [%equal:
            [ `Coinbase_inc
            | `Fee_payer_dec
            | `Fee_receiver_inc
            | `Account_creation_fee_via_fee_receiver of Unsigned.UInt64.t ]]
        ~plan ~f:(fun ~related_operations ~operation_identifier op ->
          (* All internal commands succeed if they're in blocks *)
          let status = Some (Operation_statuses.name `Success) in
          match op.label with
          | `Coinbase_inc ->
              M.return
                { Operation.operation_identifier
                ; related_operations
                ; status
                ; account =
                    Some
                      (account_id t.receiver
                         (`Token_id Amount_of.Token_id.default) )
                ; _type = Operation_types.name `Coinbase_inc
                ; amount =
                    Some
                      (Amount_of.token (`Token_id Amount_of.Token_id.default)
                         t.fee )
                ; coin_change = None
                ; metadata = None
                }
          | `Fee_receiver_inc ->
              M.return
                { Operation.operation_identifier
                ; related_operations
                ; status
                ; account = Some (account_id t.receiver t.token)
                ; _type = Operation_types.name `Fee_receiver_inc
                ; amount = Some (Amount_of.token t.token t.fee)
                ; coin_change = None
                ; metadata = None
                }
          | `Fee_payer_dec ->
              let open M.Let_syntax in
              let%map coinbase_receiver =
                match t.coinbase_receiver with
                | Some r ->
                    M.return r
                | None ->
                    M.fail
                      (Errors.create
                         ~context:
                           "This operation existing (fee payer dec within \
                            Internal_command) demands a coinbase receiver to \
                            exist. Please report this bug."
                         `Invariant_violation )
              in
              { Operation.operation_identifier
              ; related_operations
              ; status
              ; account =
                  Some
                    (account_id coinbase_receiver
                       (`Token_id Amount_of.Token_id.default) )
              ; _type = Operation_types.name `Fee_payer_dec
              ; amount = Some Amount_of.(negated (mina t.fee))
              ; coin_change = None
              ; metadata = None
              }
          | `Account_creation_fee_via_fee_receiver account_creation_fee ->
              M.return
                { Operation.operation_identifier
                ; related_operations
                ; status
                ; account =
                    Some
                      (account_id t.receiver
                         (`Token_id Amount_of.Token_id.default) )
                ; _type =
                    Operation_types.name `Account_creation_fee_via_fee_receiver
                ; amount = Some Amount_of.(negated @@ mina account_creation_fee)
                ; coin_change = None
                ; metadata = None
                } )

    let to_transaction info =
      let open M.Let_syntax in
      let%map operations = to_operations info in
      { Transaction.transaction_identifier =
          (* prepend the sequence number, secondary sequence number and kind to the transaction hash
             duplicate hashes are possible in the archive database, with differing
             "type" fields, which correspond to the "kind" here
          *)
          { Transaction_identifier.hash =
              sprintf "%s:%s:%s:%s" (Kind.to_string info.kind)
                (Int.to_string info.sequence_no)
                (Int.to_string info.secondary_sequence_no)
                info.hash
          }
      ; operations
      ; metadata = None
      ; related_transactions = []
      }
  end

  let dummies =
    [ { kind = `Coinbase
      ; receiver = `Pk "Eve"
      ; receiver_account_creation_fee_paid = None
      ; fee = Unsigned.UInt64.of_int 20_000_000_000
      ; token = `Token_id Amount_of.Token_id.default
      ; sequence_no = 1
      ; secondary_sequence_no = 0
      ; hash = "COINBASE_1"
      ; coinbase_receiver = None
      }
    ; { kind = `Fee_transfer
      ; receiver = `Pk "Alice"
      ; receiver_account_creation_fee_paid = None
      ; fee = Unsigned.UInt64.of_int 30_000_000_000
      ; token = `Token_id Amount_of.Token_id.default
      ; sequence_no = 1
      ; secondary_sequence_no = 0
      ; hash = "FEE_TRANSFER"
      ; coinbase_receiver = None
      }
    ]
end

module User_command_info = struct
  include User_command_info

  let to_transaction info =
    { Transaction.transaction_identifier =
        { Transaction_identifier.hash = info.hash }
    ; operations = User_command_info.to_operations' info
    ; metadata =
        Option.bind info.memo ~f:(fun base58_check ->
            try
              let memo =
                let open Mina_base.Signed_command_memo in
                base58_check |> of_base58_check_exn |> to_string_hum
              in
              let nonce = ("nonce", `Int (Unsigned.UInt32.to_int info.nonce)) in
              Some
                (`Assoc
                  ( if String.is_empty memo then [ nonce ]
                  else [ nonce; ("memo", `String memo) ] ) )
            with _ -> None )
    ; related_transactions = []
    }

  module T (M : Monad_fail.S) = struct
    let to_transaction info = M.return @@ to_transaction info
  end
end

module Zkapp_account_update_info = struct
  type t =
    { authorization_kind : string
    ; account : [ `Pk of string ]
    ; balance_change : string
    ; increment_nonce : bool
    ; may_use_token : string
    ; call_depth : Unsigned_extended.UInt64.t
    ; use_full_commitment : bool
    ; status : [ `Success | `Failed ]
    ; token : [ `Token_id of string ]
    }
  [@@deriving to_yojson, equal]

  let dummies =
    [ { authorization_kind = "OK"
      ; account = `Pk "Eve"
      ; balance_change = "-1000000"
      ; increment_nonce = false
      ; may_use_token = "no"
      ; call_depth = Unsigned.UInt64.of_int 10
      ; use_full_commitment = true
      ; status = `Success
      ; token = `Token_id Amount_of.Token_id.default
      }
    ; { authorization_kind = "NOK"
      ; account = `Pk "Alice"
      ; balance_change = "20000000"
      ; increment_nonce = true
      ; may_use_token = "no"
      ; call_depth = Unsigned.UInt64.of_int 20
      ; use_full_commitment = false
      ; status = `Failed
      ; token = `Token_id Amount_of.Token_id.default
      }
    ]
end

module Zkapp_command_info = struct
  type t =
    { fee : Unsigned_extended.UInt64.t
    ; fee_payer : [ `Pk of string ]
    ; valid_until : Unsigned_extended.UInt32.t option
    ; nonce : Unsigned_extended.UInt32.t
    ; sequence_no : int
    ; memo : string option
    ; hash : string
    ; failure_reasons : string list
    ; account_updates : Zkapp_account_update_info.t list
    }
  [@@deriving to_yojson]

  let logger = Logger.create ()

  module T (M : Monad_fail.S) = struct
    module Op_build = Op.T (M)

    let to_operations (t : t) =
      Op_build.build
        ~a_eq:
          [%equal:
            [ `Zkapp_fee_payer_dec
            | `Zkapp_account_update of Zkapp_account_update_info.t ]]
        ~plan:
          ( { Op.label = `Zkapp_fee_payer_dec; related_to = None }
          :: List.map t.account_updates ~f:(fun upd ->
                 { Op.label = `Zkapp_account_update upd; related_to = None } )
          )
        ~f:(fun ~related_operations ~operation_identifier op ->
          let default_token = `Token_id Amount_of.Token_id.default in
          match op.label with
          | `Zkapp_fee_payer_dec ->
              M.return
                { Operation.operation_identifier
                ; related_operations
                ; status = Some (Operation_statuses.name `Success)
                ; account = Some (account_id t.fee_payer default_token)
                ; _type = Operation_types.name `Zkapp_fee_payer_dec
                ; amount = Some Amount_of.(negated @@ token default_token t.fee)
                ; coin_change = None
                ; metadata = None
                }
          | `Zkapp_account_update upd ->
              let status = Some (Operation_statuses.name upd.status) in
              let amount =
                match String.chop_prefix ~prefix:"-" upd.balance_change with
                | Some amount ->
                    Some
                      Amount_of.(
                        negated @@ token upd.token
                        @@ Unsigned_extended.UInt64.of_string amount)
                | None ->
                    Some
                      Amount_of.(
                        token upd.token
                        @@ Unsigned_extended.UInt64.of_string upd.balance_change)
              in
              M.return
                { Operation.operation_identifier
                ; related_operations
                ; status
                ; account = Some (account_id upd.account upd.token)
                ; _type = Operation_types.name `Zkapp_balance_update
                ; amount
                ; coin_change = None
                ; metadata = None
                } )

    let to_transaction cmd =
      let open M.Let_syntax in
      let%map operations = to_operations cmd in
      let nonce = ("nonce", `Int (Unsigned.UInt32.to_int cmd.nonce)) in
      let memo_field =
        Option.bind cmd.memo ~f:(fun base58_check ->
            try
              let memo =
                let open Mina_base.Signed_command_memo in
                base58_check |> of_base58_check_exn |> to_string_hum
              in
              if String.is_empty memo then None else Some ("memo", `String memo)
            with exn ->
              [%log warn]
                ~metadata:
                  [ ("memo", `String base58_check)
                  ; ("hash", `String cmd.hash)
                  ; ("error", `String (Exn.to_string exn))
                  ]
                "Failed to base58-check decode zkapp-command memo $memo for \
                 transaction $hash; omitting memo from metadata: $error" ;
              None )
      in
      let metadata_fields =
        match memo_field with Some m -> [ nonce; m ] | None -> [ nonce ]
      in
      { Transaction.transaction_identifier =
          { Transaction_identifier.hash = cmd.hash }
      ; operations
      ; metadata = Some (`Assoc metadata_fields)
      ; related_transactions = []
      }
  end

  let dummies =
    [ { fee_payer = `Pk "Eve"
      ; fee = Unsigned.UInt64.of_int 20_000_000_000
      ; sequence_no = 1
      ; hash = "COMMAND_1"
      ; failure_reasons = []
      ; valid_until = Some (Unsigned.UInt32.of_int 10_000)
      ; nonce = Unsigned.UInt32.of_int 3
      ; memo = Some "Hey"
      ; account_updates = Zkapp_account_update_info.dummies
      }
    ; { fee_payer = `Pk "Alice"
      ; fee = Unsigned.UInt64.of_int 10_000_000_000
      ; sequence_no = 2
      ; hash = "COMMAND_2"
      ; failure_reasons = [ "Failure1" ]
      ; valid_until = Some (Unsigned.UInt32.of_int 20_000)
      ; nonce = Unsigned.UInt32.of_int 2
      ; memo = None
      ; account_updates = Zkapp_account_update_info.dummies
      }
    ]

  let%test_module "Zkapp_command_info.to_transaction metadata" =
    ( module struct
      module T_result = T (Result)

      let metadata_fields cmd =
        match T_result.to_transaction cmd with
        | Ok { metadata = Some (`Assoc fields); _ } ->
            fields
        | Ok _ ->
            failwith "expected metadata to be Some (`Assoc _)"
        | Error _ ->
            failwith "to_transaction returned Error for a valid command"

      let find_field fields key = List.Assoc.find fields ~equal:String.equal key

      let%test_unit "nonce is always present (memo = None)" =
        let cmd = List.nth_exn dummies 1 in
        let fields = metadata_fields cmd in
        match find_field fields "nonce" with
        | Some (`Int n) ->
            [%test_eq: int] n (Unsigned.UInt32.to_int cmd.nonce)
        | _ ->
            failwith "expected nonce field to be Some (`Int _)"

      let%test_unit "nonce is present even when memo is unparseable" =
        let cmd = List.nth_exn dummies 0 in
        let fields = metadata_fields cmd in
        ( match find_field fields "nonce" with
        | Some (`Int n) ->
            [%test_eq: int] n (Unsigned.UInt32.to_int cmd.nonce)
        | _ ->
            failwith "expected nonce field to be Some (`Int _)" ) ;
        [%test_eq: bool] (Option.is_some (find_field fields "memo")) false

      let%test_unit "memo included when valid base58 check string" =
        let memo_text = "rosetta-okx-test" in
        let memo_base58 =
          Mina_base.Signed_command_memo.(
            create_from_string_exn memo_text |> to_base58_check)
        in
        let cmd = { (List.nth_exn dummies 0) with memo = Some memo_base58 } in
        let fields = metadata_fields cmd in
        ( match find_field fields "nonce" with
        | Some (`Int _) ->
            ()
        | _ ->
            failwith "expected nonce field" ) ;
        match find_field fields "memo" with
        | Some (`String m) ->
            [%test_eq: string] m memo_text
        | _ ->
            failwith "expected memo field to be Some (`String _)"

      let%test_unit "memo omitted when valid base58 decodes to empty string" =
        let empty_base58 =
          Mina_base.Signed_command_memo.(to_base58_check empty)
        in
        let cmd = { (List.nth_exn dummies 0) with memo = Some empty_base58 } in
        let fields = metadata_fields cmd in
        ( match find_field fields "nonce" with
        | Some (`Int _) ->
            ()
        | _ ->
            failwith "expected nonce field" ) ;
        [%test_eq: bool] (Option.is_some (find_field fields "memo")) false

      (* Regression pin for OKX Bug 1: metadata must never be None, since
         that was the original symptom (zk-tx responses lacked the nonce
         entirely). *)
      let%test_unit "metadata is never None across all dummies" =
        List.iter dummies ~f:(fun cmd ->
            match T_result.to_transaction cmd with
            | Ok { metadata = Some _; _ } ->
                ()
            | Ok { metadata = None; _ } ->
                failwith
                  (sprintf "metadata is None for zkapp command with hash %s"
                     cmd.hash )
            | Error _ ->
                failwith "to_transaction returned Error for a dummy command" )
    end )
end
