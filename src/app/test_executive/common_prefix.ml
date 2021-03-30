open Core_kernel
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
    { default with
      requires_graphql= true
    ; block_producers=
        [ {balance= "1000"; timing= Untimed}
        ; {balance= "1000"; timing= Untimed}
        ; {balance= "1000"; timing= Untimed}
        ; {balance= "1000"; timing= Untimed} ]
    ; num_snark_workers= 0 }

  let expected_error_event_reprs = []

  let check_common_prefixes ?number_of_blocks:(n = 3) chains =
    let recent_chains =
      List.map chains ~f:(fun chain ->
          List.take (List.rev chain) n |> Hash_set.of_list (module String) )
    in
    let common_prefixes =
      List.fold ~f:Hash_set.inter
        ~init:(List.hd_exn recent_chains)
        (List.tl_exn recent_chains)
    in
    let length = Hash_set.length common_prefixes in
    if length = 0 then
      Malleable_error.soft_error ()
        (Error.of_string
           (sprintf
              "Chains don't have any common prefixes among their most recent \
               %d blocks"
              n))
    else if length < n then
      Malleable_error.soft_error ()
        (Error.of_string
           (sprintf
              !"Chains only have %d common prefixes, expected %d common \
                prefixes"
              length n))
    else Malleable_error.return ()

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let block_producers = Network.block_producers network in
    [%log info] "common prefix test: waiting for block producers to initialize" ;
    let%bind () =
      Malleable_error.List.iter block_producers ~f:(fun bp ->
          wait_for t @@ Wait_condition.node_to_initialize bp )
    in
    [%log info]
      "common prefix test: waiting for 6 blocks to be produced on the network" ;
    let%bind () = wait_for t (Wait_condition.blocks_to_be_produced 6) in
    [%log info] "common prefix test: collecting best chains from nodes" ;
    let%bind chains =
      Malleable_error.List.map block_producers ~f:(fun bp ->
          Network.Node.best_chain ~logger bp )
    in
    [%log info]
      ~metadata:
        [ ( "chains"
          , `List
              (List.map chains ~f:(fun chain ->
                   `List (List.map chain ~f:(fun hash -> `String hash)) )) ) ]
      "common prefix test: successfully collected best chains" ;
    check_common_prefixes chains
end
