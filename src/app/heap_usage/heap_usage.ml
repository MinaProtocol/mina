(* heap_usage.ml *)

open Core_kernel
open Async

let print_heap_usage name v =
  let repr = Obj.repr v in
  (* reachable_words may be 0, so it doesn't include size *)
  let words = Obj.size repr + Obj.reachable_words repr in
  Format.printf "Data of type %-36s uses %6d heap words = %8d bytes@." name
    words (words * Sys.word_size)

let main () =
  let open Values in
  (*   print_heap_usage "Account.t (w/ zkapp)" account ; *)
  print_heap_usage "Zkapp_command.t" zkapp_command ;
  (* print_heap_usage "Ledger.Db.path.t" merkle_path ;
     print_heap_usage "Protocol_state.t" protocol_state ;
     print_heap_usage "Pending_coinbase.t" pending_coinbase ;
     print_heap_usage "Staged_ledger_diff.t (payments)" staged_ledger_diff ;
     print_heap_usage "Parallel_scan.Base.t (coinbase)"
       scan_state_base_node_coinbase ;
     print_heap_usage "Parallel_scan.Base.t (payment)" scan_state_base_node_payment ;
     print_heap_usage "Parallel_scan.Base.t (zkApp)" scan_state_base_node_zkapp ;
       print_heap_usage "Parallel_scan.Merge.t" scan_state_merge_node ; *)
  (*  print_heap_usage "Block.t (maximum zkApp sizes)" block_max_zkapps ; *)
  Deferred.unit

let () =
  Command.(
    run
      (async ~summary:"Print heap usage of selected Mina data structures"
         (let%map.Command () = Let_syntax.return () in
          main ) ))
