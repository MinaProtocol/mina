open Core
open Async
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  (* TODO: find a way to avoid this type alias (first class module signatures restrictions make this tricky) *)
  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config =
    let open Test_config in
    let open Test_config.Wallet in
    { default with
      requires_graphql = true
    ; block_producers =
        [ { balance = "700000"; timing = Untimed }
        ; { balance = "700000"; timing = Untimed }
        ; { balance = "800000"; timing = Untimed }
        ]
    }

  let run network t =
    let open Network in
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let all_nodes = Network.all_nodes network in
    [%log info] "peers_list"
      ~metadata:
        [ ("peers", `List (List.map all_nodes ~f:(fun n -> `String (Node.id n))))
        ] ;
    let[@warning "-8"] [ node_a; node_b; node_c ] =
      Network.block_producers network
    in
    (* witness the node_c frontier load on initialization *)
    let%bind () =
      wait_for t @@ Wait_condition.persisted_frontier_loaded node_c
    in
    let%bind () = wait_for t (Wait_condition.nodes_to_initialize all_nodes) in
    let%bind initial_connectivity_data =
      Util.fetch_connectivity_data ~logger all_nodes
    in
    let%bind () =
      section "network is fully connected upon initialization"
        (Util.assert_peers_completely_connected initial_connectivity_data)
    in
    let%bind () =
      section
        "network can't be partitioned if 2 nodes are hypothetically taken \
         offline"
        (Util.assert_peers_cant_be_partitioned ~max_disconnections:2
           initial_connectivity_data )
    in
    (* a couple of transactions, so the persisted transition frontier is not trivial *)
    let%bind () =
      section_hard "send a payment"
        (let%bind sender_pub_key = Util.pub_key_of_node node_c in
         let%bind receiver_pub_key = Util.pub_key_of_node node_b in
         let%bind { hash = txn_hash; _ } =
           Node.must_send_payment ~logger node_c ~sender_pub_key
             ~receiver_pub_key
             ~amount:(Currency.Amount.of_int 1_000_000)
             ~fee:(Currency.Fee.of_int 10_000_000)
         in
         wait_for t
           (Wait_condition.signed_command_to_be_included_in_frontier ~txn_hash
              ~node_included_in:(`Node node_c) ) )
    in
    let zkapp_account_keypair = Signature_lib.Keypair.create () in
    let%bind () =
      let wait_for_zkapp parties =
        let%map () =
          wait_for t
          @@ Wait_condition.zkapp_to_be_included_in_frontier ~has_failures:false
               ~parties
        in
        [%log info] "ZkApp transaction included in transition frontier"
      in
      section_hard "send a zkApp to create an account"
        (let%bind parties_create_accounts =
           let amount = Currency.Amount.of_int 10_000_000_000 in
           let nonce = Mina_base.Account.Nonce.(succ zero) in
           let memo =
             Mina_base.Signed_command_memo.create_from_string_exn
               "Zkapp create account"
           in
           let fee = Currency.Fee.of_int 20_000_000 in
           let sender_kp =
             (Option.value_exn (Node.network_keypair node_c)).keypair
           in
           let (parties_spec : Transaction_snark.For_tests.Spec.t) =
             { sender = (sender_kp, nonce)
             ; fee
             ; fee_payer = None
             ; receivers = []
             ; amount
             ; zkapp_account_keypairs = [ zkapp_account_keypair ]
             ; memo
             ; new_zkapp_account = true
             ; snapp_update = Mina_base.Party.Update.dummy
             ; current_auth = Mina_base.Permissions.Auth_required.Signature
             ; call_data = Snark_params.Tick.Field.zero
             ; events = []
             ; sequence_events = []
             ; preconditions = None
             }
           in
           return
           @@ Transaction_snark.For_tests.deploy_snapp
                ~constraint_constants:(Network.constraint_constants network)
                parties_spec
         in
         let%bind () = send_zkapp ~logger node_c parties_create_accounts in
         wait_for_zkapp parties_create_accounts )
    in
    let%bind () =
      section "Checking for new zkApp account in node about to be stopped"
        (let pk =
           zkapp_account_keypair.public_key |> Signature_lib.Public_key.compress
         in
         let account_id =
           Mina_base.Account_id.create pk Mina_base.Token_id.default
         in
         let%map _account_data =
           Node.must_get_account_data ~logger node_c ~account_id
         in
         () )
    in
    [%log info] "zkApp account was created on node about to be stopped" ;
    let%bind () =
      section "blocks are produced"
        (wait_for t (Wait_condition.blocks_to_be_produced 1))
    in
    let%bind () =
      section "short bootstrap"
        (let%bind () = Node.stop node_c in
         [%log info] "%s stopped, will now wait for blocks to be produced"
           (Node.id node_c) ;
         let%bind () =
           wait_for t
             ( Wait_condition.blocks_to_be_produced 1
             (* Extend the wait timeout, only 2/3 of stake is online. *)
             |> Wait_condition.with_timeouts
                  ~soft_timeout:(Network_time_span.Slots 3)
                  ~hard_timeout:(Network_time_span.Slots 6) )
         in
         let%bind () = Node.start ~fresh_state:true node_c in
         [%log info]
           "%s started again, will now wait for this node to initialize"
           (Node.id node_c) ;
         (* we've already waited for the loading of the node_c frontier on initialization
            so the event here must be the frontier loading on the node_c restart
         *)
         let%bind () =
           wait_for t @@ Wait_condition.persisted_frontier_loaded node_c
         in
         let%bind () = wait_for t @@ Wait_condition.node_to_initialize node_c in
         wait_for t
           ( Wait_condition.nodes_to_synchronize [ node_a; node_b; node_c ]
           |> Wait_condition.with_timeouts
                ~hard_timeout:
                  (Network_time_span.Literal
                     (Time.Span.of_ms (15. *. 60. *. 1000.)) ) ) )
    in
    section "network is fully connected after one node was restarted"
      (let%bind () = Malleable_error.lift (after (Time.Span.of_sec 240.0)) in
       let%bind final_connectivity_data =
         Util.fetch_connectivity_data ~logger all_nodes
       in
       Util.assert_peers_completely_connected final_connectivity_data )
end
