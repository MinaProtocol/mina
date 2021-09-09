open Core
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  (* TODO: find a way to avoid this type alias (first class module signatures restrictions make this tricky) *)
  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config =
    let open Test_config in
    let open Test_config.Block_producer in
    { default with
      block_producers=
        [{balance= "1000"; timing= Untimed}; {balance= "1000"; timing= Untimed}]
    ; num_snark_workers= 0 }

  let expected_error_event_reprs = []

  let run network t =
    let open Network in
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let node_a = List.nth_exn (Network.block_producers network) 0 in
    let node_b = List.nth_exn (Network.block_producers network) 1 in
    (* TODO: bulk wait for init *)
    let%bind () = wait_for t (Wait_condition.node_to_initialize node_a) in
    let%bind () = wait_for t (Wait_condition.node_to_initialize node_b) in
    let%bind _ = wait_for t (Wait_condition.blocks_to_be_produced 2) in
    let%bind () = Node.stop node_b in
    let%bind _ = wait_for t (Wait_condition.blocks_to_be_produced 1) in
    let%bind () = Node.start ~fresh_state:true node_b in
    let%bind () = wait_for t (Wait_condition.node_to_initialize node_b) in
    let%map () =
      wait_for t
        ( Wait_condition.nodes_to_synchronize [node_a; node_b]
        |> Wait_condition.with_timeouts
             ~hard_timeout:
               (Network_time_span.Literal
                  (Time.Span.of_ms (15. *. 60. *. 1000.))) )
    in
    [%log info] "bootstrap_test completed successfully"
end
