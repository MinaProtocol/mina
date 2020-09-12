open Integration_test_lib

module Make (Engine : Engine_intf) = struct
  open Engine

  (* TODO: find a way to avoid this type alias (first class module signatures restrictions make this tricky) *)
  type network = Network.t

  type log_engine = Log_engine.t

  let config =
    let open Test_config in
    let open Test_config.Block_producer in
    {default with block_producers= [{balance= "1000"}]; num_snark_workers= 0}

  let run network log_engine =
    let open Network in
    let open Malleable_error.Let_syntax in
    let block_producer = List.nth network.block_producers 0 in
    let%bind () = Log_engine.wait_for_init block_producer log_engine in
    Log_engine.wait_for ~blocks:1 ~timeout:(`Slots 30) log_engine
end
