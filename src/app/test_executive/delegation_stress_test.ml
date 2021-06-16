open Core_kernel
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let alternate_producer_balance = "20000000"

  let delegater_balance = "1000"

  let delegation_count = 40_000

  let config =
    let open Test_config in
    let open Test_config.Account_config in
    let block_producers =
      [ {balance= "0"; timing= Untimed; delegate= None}
      ; {balance= alternate_producer_balance; timing= Untimed; delegate= None}
      ]
    in
    let delegating_account =
      { balance= delegater_balance
      ; timing= Untimed
      ; delegate= Some (Block_producer 0) }
    in
    let additional_accounts =
      List.init delegation_count ~f:(Fn.const delegating_account)
    in
    { default with
      block_producers
    ; additional_accounts
        (* this test does not run long enough to require snark work *)
    ; num_snark_workers= 0 }

  let run network t =
    let open Malleable_error.Let_syntax in
    let[@warning "-8"] [bp1; bp2] = Network.block_producers network in
    let%bind () = wait_for t (Wait_condition.node_to_initialize bp1) in
    let%bind () = wait_for t (Wait_condition.node_to_initialize bp2) in
    (* This tests is the block producer can keep up with the VRF evaluations.
     * If the block producer were to fall behind the VRF evaluations, we would expect
     * it to be unable to produce blocks since it wouldn't find the winning slots
     * in time. If the VRF evaluations are starving the async scheduler, we would
     * expect it to be unable to stay in sync with the other block producer. *)
    let%bind () =
      section "blocks are produced by producer with lots of delegations"
        (wait_for t (Wait_condition.blocks_to_be_produced_by ~node:bp1 6))
    in
    section
      "block producer with lots of delegations is still in sync after \
       producing some blocks"
      (wait_for t
         ( Wait_condition.nodes_to_synchronize [bp1; bp2]
         |> Wait_condition.with_timeouts
              ~hard_timeout:(Network_time_span.Literal (Time.Span.of_sec 15.0))
         ))
end
