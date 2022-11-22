open Core
open Integration_test_lib
open Mina_base

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

  let run network t =
    let open Malleable_error.Let_syntax in
    (* Setup *)
    let logger = Logger.create () in
    let block_producer_nodes = Network.block_producers network in
    let node = List.hd_exn block_producer_nodes in
    let%bind fee_payer_pk = Util.pub_key_of_node node in
    let fee = Currency.Fee.of_nanomina_int_exn 10_000_000 in
    let memo = Signed_command_memo.create_from_string_exn "Zkapp update all" in
    let with_timeout =
      let soft_slots = 3 in
      let soft_timeout = Network_time_span.Slots soft_slots in
      let hard_timeout = Network_time_span.Slots (soft_slots * 2) in
      Wait_condition.with_timeouts ~soft_timeout ~hard_timeout
    in
    let wait_for_zkapp ~has_failures zkapp_command =
      let%map () =
        wait_for t @@ with_timeout
        @@ Wait_condition.zkapp_to_be_included_in_frontier ~has_failures
             ~zkapp_command
      in
      [%log info] "zkApp transaction included in transition frontier"
    in
    (* Initialize *)
    let%bind () =
      section_hard "Wait for nodes to initialize"
        (wait_for t
           (Wait_condition.nodes_to_initialize
              ( Network.seeds network @ block_producer_nodes
              @ Network.snark_coordinators network ) ) )
    in
    (* Setup transactions*)
    let invalid_nonce_transaction =
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
    let valid_nonce_transaction =
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
      section "Send a zkApp transaction with an invalid account_update nonce"
        (send_zkapp ~logger node invalid_nonce_transaction)
    in
    (* Submit transactions*)
    let%bind () =
      section "Send a zkApp transaction with an valid account_update nonce"
        (send_zkapp ~logger node valid_nonce_transaction)
    in
    (* Check transactions*)
    let%bind () =
      section
        "Wait for zkApp transaction with invalid nonce to be rejected by \
         transition frontier"
        (wait_for_zkapp ~has_failures:true invalid_nonce_transaction)
    in
    let%bind () =
      section
        "Wait for zkApp transaction with invalid nonce to be accepted by \
         transition frontier"
        (wait_for_zkapp ~has_failures:false valid_nonce_transaction)
    in
    (* End test *)
    section_hard "Running replayer"
      (let%bind logs =
         Network.Node.run_replayer ~logger
           (List.hd_exn @@ Network.archive_nodes network)
       in
       check_replayer_logs ~logger logs )
end
