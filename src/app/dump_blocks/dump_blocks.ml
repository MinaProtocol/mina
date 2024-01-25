open Frontier_base
open Full_frontier.For_tests
open Cmdliner
open Core
open Archive_lib

  let logger = Logger.create ()


  let proof_level = Genesis_constants.Proof_level.None

    let precomputed_values =
      { (Lazy.force Precomputed_values.for_unit_tests) with proof_level }

    let constraint_constants = precomputed_values.constraint_constants

    
    module Genesis_ledger = (val Genesis_ledger.for_unit_tests)

let accounts_with_secret_keys = (Lazy.force Genesis_ledger.accounts)

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
      Core_kernel.eprintf
        !"Randomly generated block, sexp:\n" ;
      Core_kernel.printf !"%{sexp:Mina_block.Precomputed.t}\n"
        precomputed ;
      Core_kernel.eprintf
        !"Randomly generated block, json:\n" ;
      Core_kernel.printf !"%{Yojson.Safe}\n"
        (Mina_block.Precomputed.to_yojson precomputed) ;
      clean_up_persistent_root ~frontier )

    
let gen_single_block =
  Command.basic
    ~summary:
      "Generates single arbitrary precomputed block and prints it to the output"
  (Command.Param.return (fun () ->
      let verifier = verifier () in
      Core_kernel.Quickcheck.test (gen_breadcrumb ~verifier ()) ~trials:1 ~f
    ))

let gen_sequence_of_blocks = 
  Command.basic
    ~summary:
      "Generates sequence of blocks to specified location"
    Command.Let_syntax.(
      let%map_open size =
      flag "--size" ~aliases:[ "-s" ] (required int)
        ~doc:"sequence size"
      and output_folder = Command.Param.anon Command.Anons.("OUTPUT_FOLDER" %: Command.Param.string) in
      fun () ->
        Archive_lib.Processor.For_test.dump_blocks ~trials:1 ~size ~precomputed_values ~logger ~verifier:(verifier ()) ~accounts_with_secret_keys ~path:output_folder
     )

let commands =
  [ ( "single", gen_single_block )
    ; ( "sequence", gen_sequence_of_blocks  )
  ]


let () =
Command.run
  (Command.group ~summary:"Dump blocks main commands"
     ~preserve_subcommand_order:() commands )

 
