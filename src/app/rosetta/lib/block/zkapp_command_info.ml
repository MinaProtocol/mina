open! Core_kernel
open Rosetta_lib
open Rosetta_models

let account_id = User_command_info.account_id

type t =
  { fee : Unsigned_extended.UInt64.t
  ; fee_payer : [ `Pk of string ]
  ; valid_until : Unsigned_extended.UInt32.t option
  ; nonce : Unsigned_extended.UInt32.t
  ; token : [ `Token_id of string ]
  ; sequence_no : int
  ; memo : string option
  ; hash : string
  ; failure_reasons : string list
  }
[@@deriving to_yojson]

module T (M : Monad_fail.S) = struct
  module Op_build = Op.T (M)

  let to_operations (t : t) : (Operation.t list, Errors.t) M.t =
    (* We choose to represent the dec-side of fee transfers from txns from the
     * canonical user command that created them so we are able consistently
     * produce more balance changing operations in the mempool or a block.
     * *)
    Op_build.build ~a_eq:[%equal: [ `Zkapp_fee_payer_dec ]] ~plan:[]
      ~f:(fun ~related_operations ~operation_identifier op ->
        let status =
          match t.failure_reasons with
          | [] ->
              Some (Operation_statuses.name `Success)
          | _ ->
              Some (Operation_statuses.name `Failed)
        in
        match op.label with
        | `Zkapp_fee_payer_dec ->
            M.return
              { Operation.operation_identifier
              ; related_operations
              ; status
              ; account =
                  Some
                    (account_id t.fee_payer
                       (`Token_id Amount_of.Token_id.default) )
              ; _type = Operation_types.name `Zkapp_fee_payer_dec
              ; amount =
                  Some
                    (Amount_of.token (`Token_id Amount_of.Token_id.default)
                       t.fee )
              ; coin_change = None
              ; metadata = None
              } )
end

let dummies =
  [ { fee_payer = `Pk "Eve"
    ; fee = Unsigned.UInt64.of_int 20_000_000_000
    ; token = `Token_id Amount_of.Token_id.default
    ; sequence_no = 1
    ; hash = "COMMAND_1"
    ; failure_reasons = []
    ; valid_until = Some (Unsigned.UInt32.of_int 10_000)
    ; nonce = Unsigned.UInt32.of_int 3
    ; memo = Some "Hey"
    }
  ; { fee_payer = `Pk "Alice"
    ; fee = Unsigned.UInt64.of_int 10_000_000_000
    ; token = `Token_id Amount_of.Token_id.default
    ; sequence_no = 2
    ; hash = "COMMAND_2"
    ; failure_reasons = [ "Failure1" ]
    ; valid_until = Some (Unsigned.UInt32.of_int 20_000)
    ; nonce = Unsigned.UInt32.of_int 2
    ; memo = None
    }
  ]
