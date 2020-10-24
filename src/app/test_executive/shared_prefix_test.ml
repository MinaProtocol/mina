open Core
open Integration_test_lib
open Currency

module Make (Engine : Engine_intf) = struct
  open Engine

  (* TODO: find a way to avoid this type alias (first class module signatures restrictions make this tricky) *)
  type network = Network.t

  type log_engine = Log_engine.t

  let config =
    let open Test_config in
    let open Test_config.Block_producer in
    let timing : Coda_base.Account_timing.t =
      Timed
        { initial_minimum_balance= Balance.of_int 1000
        ; cliff_time= Coda_numbers.Global_slot.of_int 4
        ; vesting_period= Coda_numbers.Global_slot.of_int 2
        ; vesting_increment= Amount.of_int 50_000_000_000 }
    in
    { default with
      block_producers=
        [ {balance= "1000"; timing}
        ; {balance= "1000"; timing}
        ; {balance= "1000"; timing} ]
    ; num_snark_workers= 0 }

  let run network log_engine =
    let open Network in
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    [%log info] "shared_prefix_test: started" ;
    let wait_for_init_partial node =
      Log_engine.wait_for_init node log_engine
    in
    let%bind () =
      Malleable_error.List.iter network.block_producers
        ~f:wait_for_init_partial
    in
    [%log info] "shared_prefix_test: done waiting for initialization" ;
    let peer_list = network.block_producers in
    let get_node_name_partial = Node.get_node_name ~logger in
    let%bind query_result =
      Malleable_error.List.map peer_list ~f:get_node_name_partial
    in
    [%log info] "shared_prefix_test: successfully made graphql querry" ;
    let prefix = "TEMP" in
    let names, _ = List.unzip query_result in
    List.map names ~f:(fun x -> assert (String.equal x prefix))
end
