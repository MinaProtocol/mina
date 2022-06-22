open Core_kernel
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
        [ { balance = "1000"; timing = Untimed }
        ; { balance = "1000"; timing = Untimed }
        ]
    ; num_archive_nodes = 1
    ; num_snark_workers = 0
    }

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    (* fee for user commands *)
    let fee = Currency.Fee.of_int 10_000_000 in
    let all_nodes = Network.all_nodes network in
    let%bind () = wait_for t (Wait_condition.nodes_to_initialize all_nodes) in
    let[@warning "-8"] [ node_a; node_b ] = Network.block_producers network in
    let%bind () =
      section "Delegate all mina currency from node_b to node_a"
        (let delegation_receiver = node_a in
         let%bind delegation_receiver_pub_key =
           Util.pub_key_of_node delegation_receiver
         in
         let delegation_sender = node_b in
         let%bind delegation_sender_pub_key =
           Util.pub_key_of_node delegation_sender
         in
         let%bind { hash; _ } =
           Network.Node.must_send_delegation ~logger delegation_sender
             ~sender_pub_key:delegation_sender_pub_key
             ~receiver_pub_key:delegation_receiver_pub_key ~fee
         in
         wait_for t
           (Wait_condition.signed_command_to_be_included_in_frontier
              ~txn_hash:hash ~node_included_in:`Any_node ) )
    in
    section_hard "Running replayer"
      (let%bind logs =
         Network.Node.run_replayer ~logger
           (List.hd_exn @@ Network.archive_nodes network)
       in
       check_replayer_logs ~logger logs )
end
