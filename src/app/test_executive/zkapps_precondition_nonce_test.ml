open Core
open Async
open Integration_test_lib
open Mina_base

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config =
    let open Test_config in
    { default with
      requires_graphql = true
    ; block_producers =
        [ { balance = "8000000000"; timing = Untimed }
        ; { balance = "1000000000"; timing = Untimed }
        ]
    ; extra_genesis_accounts =
        [ { balance = "3000"; timing = Untimed }
        ; { balance = "3000"; timing = Untimed }
        ]
    ; num_archive_nodes = 1
    ; num_snark_workers = 2
    ; snark_worker_fee = "0.0001"
    ; proof_config =
        { proof_config_default with
          work_delay = Some 1
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.small
        }
    }

  let transactions_sent = ref 0

  let send_zkapp ~logger node zkapp_command =
    incr transactions_sent ;
    send_zkapp ~logger node zkapp_command

  (*
       Test plan:
       1. Create a transaction that looks like the following:
         [ fee_pay1; update1]
         - fee_pay1 updates it's nonce to 1
         - update1 should be the nonce after fee_pay1, so 1
       2. Create a transaction that looks like the following:
         [ fee_pay2; update2]
         - fee_pay2 has the precondition of 1, otherwise it should fail
         - update2 should have precondition after fee_pay2 is applied, so 2
        
      Outcome: 
        - Both transactions included in a block
        - transaction1 should have Failed status
        - transaction2 should have Applied status
        - Application order fee_pay1, fee_pay2, update1, update2

    *)

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let block_producer_nodes = Network.block_producers network in
    let%bind () =
      section_hard "Wait for nodes to initialize"
        (wait_for t
           (Wait_condition.nodes_to_initialize
              ( Network.seeds network @ block_producer_nodes
              @ Network.snark_coordinators network ) ) )
    in
    let node = List.hd_exn block_producer_nodes in
    let%bind fee_payer_pk = Util.pub_key_of_node node in
    let fee = Currency.Fee.of_nanomina_int_exn 10_000_000 in
    let memo = Signed_command_memo.create_from_string_exn "Zkapp update all" in
    let t1 =
      Zkapp_command.of_simple
        { fee_payer =
            { body =
                { public_key = fee_payer_pk
                ; fee
                ; valid_until = None
                ; nonce = Account.Nonce.of_int 0
                }
            ; authorization = Signature.dummy
            }
        ; account_updates =
            [ { body =
                  { public_key = fee_payer_pk
                  ; update = Account_update.Update.noop
                  ; token_id = Token_id.default
                  ; balance_change = Currency.Amount.Signed.zero
                  ; increment_nonce = true
                  ; events = []
                  ; sequence_events = []
                  ; call_data = Snark_params.Tick.Field.zero
                  ; call_depth = 0
                  ; preconditions =
                      { Account_update.Preconditions.network =
                          Zkapp_precondition.Protocol_state.accept
                      ; account = Nonce (Account.Nonce.of_int 1)
                      }
                  ; use_full_commitment = false
                  ; caller = Call
                  ; authorization_kind = Signature
                  }
              ; authorization = Signature Signature.dummy
              }
            ]
        ; memo
        }
    in
    let t2 =
      Zkapp_command.of_simple
        { fee_payer =
            { body =
                { public_key = fee_payer_pk
                ; fee
                ; valid_until = None
                ; nonce = Account.Nonce.of_int 1
                }
            ; authorization = Signature.dummy
            }
        ; account_updates =
            [ { body =
                  { public_key = fee_payer_pk
                  ; update = Account_update.Update.noop
                  ; token_id = Token_id.default
                  ; balance_change = Currency.Amount.Signed.zero
                  ; increment_nonce = true
                  ; events = []
                  ; sequence_events = []
                  ; call_data = Snark_params.Tick.Field.zero
                  ; call_depth = 0
                  ; preconditions =
                      { Account_update.Preconditions.network =
                          Zkapp_precondition.Protocol_state.accept
                      ; account = Nonce (Account.Nonce.of_int 2)
                      }
                  ; use_full_commitment = false
                  ; caller = Call
                  ; authorization_kind = Signature
                  }
              ; authorization = Signature Signature.dummy
              }
            ]
        ; memo
        }
    in
    let%bind () =
      section "Wait for transaction1 to be included in  transition frontier"
        (send_zkapp ~logger node t1)
    in
    let%bind () =
      section "Wait for transaction2 to be included in  transition frontier"
        (send_zkapp ~logger node t2)
    in
    (* Get transaction status to see that the transaction failed. *)
    let%bind status2 =
      section "Get transaction status" (get_transaction_status ~logger node t2)
    in

    section_hard "Running replayer"
      (let%bind logs =
         Network.Node.run_replayer ~logger
           (List.hd_exn @@ Network.archive_nodes network)
       in
       check_replayer_logs ~logger logs )
end
