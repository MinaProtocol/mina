open Core_kernel
open Rosetta_lib
open Rosetta_models

let account_id = User_command_info.account_id

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
  }
[@@deriving to_yojson]

module T (M : Monad_fail.S) = struct
  module Op_build = Op.T (M)

  let to_operations ~coinbase_receiver (t : t) :
      (Operation.t list, Errors.t) M.t =
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
          | `Account_creation_fee_via_fee_receiver of Unsigned.UInt64.t ]] ~plan
      ~f:(fun ~related_operations ~operation_identifier op ->
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
                    (account_id t.receiver (`Token_id Amount_of.Token_id.default))
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
              match coinbase_receiver with
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
                    (account_id t.receiver (`Token_id Amount_of.Token_id.default))
              ; _type =
                  Operation_types.name `Account_creation_fee_via_fee_receiver
              ; amount = Some Amount_of.(negated @@ mina account_creation_fee)
              ; coin_change = None
              ; metadata = None
              } )
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
    }
  ; { kind = `Fee_transfer
    ; receiver = `Pk "Alice"
    ; receiver_account_creation_fee_paid = None
    ; fee = Unsigned.UInt64.of_int 30_000_000_000
    ; token = `Token_id Amount_of.Token_id.default
    ; sequence_no = 1
    ; secondary_sequence_no = 0
    ; hash = "FEE_TRANSFER"
    }
  ]
