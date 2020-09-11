open Async
open Core
open Integration_test_lib

module Make (Engine : Engine_intf) = struct
  open Engine

  (* TODO: find a way to avoid this type alias (first class module signatures restrictions make this tricky) *)
  type network = Network.t

  type log_engine = Log_engine.t

  let config =
    let open Test_config in
    let open Test_config.Block_producer in
    { default with
      block_producers= [{balance= "1000"}; {balance= "1000"}]
    ; num_snark_workers= 0 }

  let run network log_engine =
    let open Network in
    let open Deferred.Or_error.Let_syntax in
    let node_a = List.nth_exn network.block_producers 0 in
    let node_b = List.nth_exn network.block_producers 1 in
    (* TODO: bulk wait for init *)
    let%bind () = Log_engine.wait_for_init node_a log_engine in
    let%bind () = Log_engine.wait_for_init node_b log_engine in
    let%bind () =
      Log_engine.wait_for ~blocks:2 ~timeout:(`Slots 20) log_engine
    in
    let%bind () = Node.stop node_b in
    let%bind () =
      Log_engine.wait_for ~blocks:3 ~timeout:(`Slots 10) log_engine
    in
    let%bind () = Node.start ~fresh_state:true node_b in
    let%bind () = Log_engine.wait_for_init node_b log_engine in
    Log_engine.wait_for_sync [node_a; node_b]
      ~timeout:(Time.Span.of_ms (15. *. 60. *. 1000.))
      log_engine
end
