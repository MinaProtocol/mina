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
      block_producers= [{balance= "1000"; timing= Untimed}]
    ; num_snark_workers= 0 }

  let expected_error_event_reprs = []

  let run network log_engine =
    let open Network in
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let block_producer = List.nth_exn network.block_producers 0 in
    let%bind () = Log_engine.wait_for_init block_producer log_engine in
    let%map _ =
      Log_engine.wait_for log_engine
        { hard_timeout= Slots 30
        ; soft_timeout= None
        ; predicate= (fun s -> s.blocks_generated >= 1) }
    in
    [%log info] "block_production_test finished successfully" ;
    ()
end
