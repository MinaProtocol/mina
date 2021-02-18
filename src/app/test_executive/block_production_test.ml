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
      block_producers= [{balance= "1000"; timing= Untimed}]
    ; num_snark_workers= 0 }

  let expected_error_event_reprs = []

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let block_producer = List.nth_exn (Network.block_producers network) 0 in
    let%bind () =
      wait_for t (Wait_condition.node_to_initialize block_producer)
    in
    let%map _ = wait_for t (Wait_condition.blocks_to_be_produced 1) in
    [%log info] "block_production_test finished successfully" ;
    ()
end
