open Core_kernel
open Rosetta_lib
open Rosetta_models

type t =
  { authorization_kind : string
  ; account : [ `Pk of string ]
  ; balance_change : string
  ; increment_nonce : bool
  ; caller : string
  ; call_depth : Unsigned_extended.UInt64.t
  ; use_full_commitment : bool
  ; status : [ `Success | `Failed ]
  ; token : [ `Token_id of string ]
  }
[@@deriving to_yojson]

module T (M : Monad_fail.S) = struct
  module Op_build = Op.T (M)

  let to_operations (t : t) : (Operation.t list, Errors.t) M.t =
    let label =
      if String.is_prefix t.balance_change ~prefix:"-" then `Balance_dec
      else `Balance_inc
    in
    let plan = [ { Op.label; related_to = None } ] in
    Op_build.build ~a_eq:[%equal: [ `Balance_inc | `Balance_dec ]] ~plan
      ~f:(fun ~related_operations ~operation_identifier op ->
        let status = Some (Operation_statuses.name t.status) in
        let amount =
          let amount =
            Unsigned_extended.UInt64.of_string
            @@ String.chop_prefix_if_exists ~prefix:"-" t.balance_change
          in
          match (t.status, op.label) with
          | `Success, `Balance_inc ->
              Some Amount_of.(token t.token amount)
          | `Success, `Balance_dec ->
              Some Amount_of.(negated @@ token t.token amount)
          | `Failed, _ ->
              None
        in
        M.return
          { Operation.operation_identifier
          ; related_operations
          ; status
          ; account = Some (User_command_info.account_id t.account t.token)
          ; _type = Operation_types.name `Zkapp_balance_update
          ; amount
          ; coin_change = None
          ; metadata = None
          } )
end

let dummies =
  [ { authorization_kind = "OK"
    ; account = `Pk "Eve"
    ; balance_change = "-1000000"
    ; increment_nonce = false
    ; caller = "caller1"
    ; call_depth = Unsigned.UInt64.of_int 10
    ; use_full_commitment = true
    ; status = `Success
    ; token = `Token_id Amount_of.Token_id.default
    }
  ; { authorization_kind = "NOK"
    ; account = `Pk "Alice"
    ; balance_change = "20000000"
    ; increment_nonce = true
    ; caller = "caller2"
    ; call_depth = Unsigned.UInt64.of_int 20
    ; use_full_commitment = false
    ; status = `Failed
    ; token = `Token_id Amount_of.Token_id.default
    }
  ]
