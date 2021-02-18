(* archive_node.ml -- generate data from archive node in cloud *)

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
      (* a few block producers, where few = 4 *)
      block_producers=
        [ {balance= "4000"; timing= Untimed}
        ; {balance= "9000"; timing= Untimed}
        ; {balance= "8000"; timing= Untimed}
        ; {balance= "17000"; timing= Untimed} ]
    ; num_archive_nodes= 1 }

  let expected_error_event_reprs = []

  (* number of minutes to let the network run, after initialization *)
  let runtime_min = 15.

  let run network t =
    let open Malleable_error.Let_syntax in
    Core_kernel.eprintf "NUM BLOCK PRODUCERS: %d\n%!"
      (List.length (Network.block_producers network)) ;
    Core_kernel.eprintf "NUM ARCHIVE NODES: %d\n%!"
      (List.length (Network.archive_nodes network)) ;
    let logger = Logger.create () in
    let block_producers = Network.block_producers network in
    [%log info] "archive node test: waiting for block producers to initialize" ;
    let%bind () =
      Malleable_error.List.iter block_producers ~f:(fun bp ->
          wait_for t (Wait_condition.node_to_initialize bp) )
    in
    [%log info] "archive node test: waiting for archive node to initialize" ;
    let archive_node = List.hd_exn @@ Network.archive_nodes network in
    let%bind () =
      wait_for t (Wait_condition.node_to_initialize archive_node)
    in
    [%log info] "archive node test: running network for %0.1f minutes"
      runtime_min ;
    let%bind.Async.Deferred.Let_syntax () =
      Async.after (Time.Span.of_min runtime_min)
    in
    let%map () = Malleable_error.return () in
    [%log info] "archive node test: done running network"

  (* let%map () =
      Network.Node.dump_archive_data ~logger archive_node
        ~data_file:"archiver.sql" 
    in
    [%log info] "archive node test: succesfully completed" *)
end
