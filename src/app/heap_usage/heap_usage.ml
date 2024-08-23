(* heap_usage.ml *)

open Core_kernel
open Async

let print_heap_usage name v =
  (* word_size is in bits *)
  let bytes_per_word = Sys.word_size / 8 in
  let repr = Obj.repr v in
  (* reachable_words may be 0 so it doesn't include size *)
  let words = Obj.size repr + Obj.reachable_words repr in
  Format.printf "Data of type %-46s uses %6d heap words = %8d bytes@." name
    words (words * bytes_per_word)

(* NOTE: Some of these values are dependant on a stateful zkapp_command value
   threaded through as an argument. It's important to not recreate it.
*)
let main ~genesis_constants ~constraint_constants () =
  let open Values in
  print_heap_usage "Account.t (w/ zkapp)" account ;
  let%bind zkapp_command =
    zkapp_command ~genesis_constants ~constraint_constants
  in
  print_heap_usage "Zkapp_command.t" zkapp_command ;
  print_heap_usage "Pickles.Side_loaded.Proof.t" @@ zkapp_proof ~zkapp_command ;
  let%bind verification_key = verification_key ~constraint_constants in
  print_heap_usage "Mina_base.Side_loaded_verification_key.t" verification_key ;
  print_heap_usage "Dummy Pickles.Side_loaded.Proof.t" dummy_proof ;
  print_heap_usage "Dummy Mina_base.Side_loaded_verification_key.t" dummy_vk ;
  print_heap_usage "Ledger.Db.path.t" merkle_path ;
  print_heap_usage "Protocol_state.t" protocol_state ;
  print_heap_usage "Pending_coinbase.t" pending_coinbase ;
  print_heap_usage "Staged_ledger_diff.t (payments)" staged_ledger_diff ;
  print_heap_usage "Parallel_scan.Base.t (coinbase)"
    scan_state_base_node_coinbase ;
  print_heap_usage "Parallel_scan.Base.t (payment)" scan_state_base_node_payment ;
  let scan_state_base_node_zkapp =
    scan_state_base_node_zkapp ~constraint_constants ~zkapp_command
  in
  print_heap_usage "Parallel_scan.Base.t (zkApp)" scan_state_base_node_zkapp ;
  print_heap_usage "Parallel_scan.Merge.t" scan_state_merge_node ;
  print_heap_usage "Transaction_snark.Statement.t" transaction_snark_statement ;
  Async.return ()

let () =
  let genesis_constants = Genesis_constants.Compiled.genesis_constants in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  Command.(
    run
      (async ~summary:"Print heap usage of selected Mina data structures"
         (let%map.Command () = Let_syntax.return () in
          main ~genesis_constants ~constraint_constants ) ))
