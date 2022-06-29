open Frontier_base
open Full_frontier.For_tests

let () =
  let open Core_kernel in
  Backtrace.elide := false ;
  Async.Scheduler.set_record_backtraces true

let logger = Logger.create ()

let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

let constraint_constants = precomputed_values.constraint_constants

(* This executable outputs random block to stderr in sexp and json
   The output is useful for src/lib/mina_block tests when the sexp/json representation changes. *)
(* TODO make generation more feauture-rich:
   * include snark works
   * include all types of transactions
   * etc.
*)
let f make_breadcrumb =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let frontier = create_frontier () in
      let root = Full_frontier.root frontier in
      let open Async_kernel.Deferred.Let_syntax in
      let%map breadcrumb = make_breadcrumb root in
      let block = Breadcrumb.block breadcrumb in
      let staged_ledger =
        Transition_frontier.Breadcrumb.staged_ledger breadcrumb
      in
      let scheduled_time =
        Mina_block.(Header.protocol_state @@ header block)
        |> Mina_state.Protocol_state.blockchain_state
        |> Mina_state.Blockchain_state.timestamp
      in
      let precomputed =
        Mina_block.Precomputed.of_block ~logger ~constraint_constants
          ~staged_ledger ~scheduled_time
          (Breadcrumb.block_with_hash breadcrumb)
      in
      Core_kernel.eprintf !"Randomly generated block, sexp:\n" ;
      Core_kernel.printf !"%{sexp:Mina_block.Precomputed.t}\n" precomputed ;
      Core_kernel.eprintf !"Randomly generated block, json:\n" ;
      Core_kernel.printf !"%{Yojson.Safe}\n"
        (Mina_block.Precomputed.to_yojson precomputed) ;
      clean_up_persistent_root ~frontier )

let () =
  let verifier = verifier () in
  Core_kernel.Quickcheck.test (gen_breadcrumb ~verifier ()) ~trials:1 ~f
