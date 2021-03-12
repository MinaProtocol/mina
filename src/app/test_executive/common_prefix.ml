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
      block_producers=
        [ {balance= "1000"; timing= Untimed}
        ; {balance= "1000"; timing= Untimed}
        ; {balance= "1000"; timing= Untimed}
        ; {balance= "1000"; timing= Untimed}
        ; {balance= "1000"; timing= Untimed} ] }

  let expected_error_event_reprs = []

  let check_common_prefixes ?number_of_blocks:(n = 5) chains =
    let recent_chains =
      List.map chains ~f:(fun chain ->
          List.take chain n |> Hash_set.of_list (module String) )
    in
    let common_prefixes =
      List.fold ~f:Hash_set.inter
        ~init:(List.hd_exn recent_chains)
        (List.tl_exn recent_chains)
    in
    if Hash_set.length common_prefixes = 0 then
      Malleable_error.of_string_hard_error_format
        "Chains don't have common prefixes among their most recent %d blocks" n
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
    [%log info] "common prefix test: running network for 5 minutes" ;
    let%bind.Async.Deferred.Let_syntax () =
      Async.after (Time.Span.of_min 5.)
    in
    [%log info] "common prefix test: done running network" ;
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
      "common prefix test: successfully made graphql query." ;
    check_common_prefixes chains
end
