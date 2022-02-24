open Core
open Async
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config =
    let open Test_config in
    let open Test_config.Block_producer in
    { default with
      requires_graphql = true
    ; block_producers =
        [ { balance = "3000000000"; timing = Untimed }
        ; { balance = "3000000000"; timing = Untimed }
        ; { balance = "3000000000"; timing = Untimed }
        ]
    ; num_snark_workers = 0
    }

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let block_producer_nodes = Network.block_producers network in
    let%bind () =
      Malleable_error.List.iter block_producer_nodes
        ~f:(Fn.compose (wait_for t) Wait_condition.node_to_initialize)
    in
    let node = List.nth_exn block_producer_nodes 0 in
    let constraint_constants =
      Genesis_constants.Constraint_constants.compiled
    in
    let%bind fee_payer_pk = Util.pub_key_of_node node in
    let%bind fee_payer_sk = Util.priv_key_of_node node in
    let (keypair : Signature_lib.Keypair.t) =
      { public_key = fee_payer_pk |> Signature_lib.Public_key.decompress_exn
      ; private_key = fee_payer_sk
      }
    in
    let snapp_keypair = Signature_lib.Keypair.create () in
    let%bind parties_create_account =
      (* construct a Parties.t, similar to snapp_test_transaction create-snapp-account *)
      let open Mina_base in
      let fee = Currency.Fee.of_int 1_000_000 in
      let amount = Currency.Amount.of_int 10_000_000_000 in
      let nonce = Account.Nonce.zero in
      let memo =
        Signed_command_memo.create_from_string_exn "Snapp create account"
      in
      let (parties_spec : Transaction_snark.For_tests.Spec.t) =
        { sender = (keypair, nonce)
        ; fee
        ; receivers = []
        ; amount
        ; snapp_account_keypair = Some snapp_keypair
        ; memo
        ; new_snapp_account = true
        ; snapp_update = Party.Update.dummy
        ; current_auth = Permissions.Auth_required.Signature
        ; call_data = Snark_params.Tick.Field.zero
        ; events = []
        ; sequence_events = []
        }
      in
      return
      @@ Transaction_snark.For_tests.deploy_snapp ~constraint_constants
           parties_spec
    in
    let%bind.Deferred parties_update_state, _vk =
      (* construct a Parties.t, similar to snapp_test_transaction update-state *)
      let open Mina_base in
      let fee = Currency.Fee.of_int 1_000_000 in
      let amount = Currency.Amount.zero in
      let nonce = Account.Nonce.of_int 2 in
      let memo =
        Signed_command_memo.create_from_string_exn "Snapp update state"
      in
      let app_state =
        let len = Snapp_state.Max_state_size.n |> Pickles_types.Nat.to_int in
        let fields =
          Quickcheck.random_value
            (Quickcheck.Generator.list_with_length len
               Snark_params.Tick.Field.gen)
        in
        List.map fields ~f:(fun field -> Snapp_basic.Set_or_keep.Set field)
        |> Snapp_state.V.of_list_exn
      in
      let (parties_spec : Transaction_snark.For_tests.Spec.t) =
        { sender = (keypair, nonce)
        ; fee
        ; receivers = []
        ; amount
        ; snapp_account_keypair = Some snapp_keypair
        ; memo
        ; new_snapp_account = false
        ; snapp_update = { Party.Update.dummy with app_state }
        ; current_auth = Permissions.Auth_required.Proof
        ; call_data = Snark_params.Tick.Field.zero
        ; events = []
        ; sequence_events = []
        }
      in
      Transaction_snark.For_tests.update_state ~constraint_constants
        parties_spec
    in
    let timeout = Network_time_span.Slots 3 in
    let%bind () =
      section "send a snapp to create a snapp account"
        ( [%log info] "Sending valid snapp" ;
          match%bind.Deferred
            Network.Node.send_snapp ~logger node ~parties:parties_create_account
          with
          | Ok _snapp_id ->
              [%log info] "Snapps transaction sent" ;
              Malleable_error.return ()
          | Error err ->
              let err_str = Error.to_string_mach err in
              [%log error] "Error sending snapp"
                ~metadata:[ ("error", `String err_str) ] ;
              Malleable_error.soft_error_format ~value:()
                "Error sending snapp: %s" err_str )
    in
    let%bind () =
      section
        "wait for snapp to create account to be included in transition frontier"
        (let%map () =
           wait_for t
           @@ Wait_condition.with_timeouts ~soft_timeout:timeout
                ~hard_timeout:timeout
           @@ Wait_condition.snapp_to_be_included_in_frontier
                ~parties:parties_create_account
         in
         [%log info] "Snapps transaction included in transition frontier")
    in
    let%bind () =
      section "send a snapp to update the snapp state"
        ( [%log info] "Sending valid snapp" ;
          match%bind.Deferred
            Network.Node.send_snapp ~logger node ~parties:parties_update_state
          with
          | Ok _snapp_id ->
              [%log info] "Snapps transaction sent" ;
              Malleable_error.return ()
          | Error err ->
              let err_str = Error.to_string_mach err in
              [%log error] "Error sending snapp"
                ~metadata:[ ("error", `String err_str) ] ;
              Malleable_error.soft_error_format ~value:()
                "Error sending snapp: %s" err_str )
    in
    let%bind () =
      section
        "wait for snapp to update state to be included in transition frontier"
        (let%map () =
           wait_for t
           @@ Wait_condition.with_timeouts ~soft_timeout:timeout
                ~hard_timeout:timeout
           @@ Wait_condition.snapp_to_be_included_in_frontier
                ~parties:parties_update_state
         in
         [%log info] "Snapps transaction included in transition frontier")
    in
    return ()
end
