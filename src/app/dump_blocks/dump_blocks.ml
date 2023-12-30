open Core

  let logger = Logger.create ()


  let proof_level = Genesis_constants.Proof_level.None

    let precomputed_values =
      { (Lazy.force Precomputed_values.for_unit_tests) with proof_level }

    let constraint_constants = precomputed_values.constraint_constants

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.create ~logger ~proof_level ~constraint_constants
            ~conf_dir:None
            ~pids:(Child_processes.Termination.create_pid_table ()) )

    
    module Genesis_ledger = (val Genesis_ledger.for_unit_tests)

let accounts_with_secret_keys = (Lazy.force Genesis_ledger.accounts)

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
        Archive_lib.Processor.For_test.dump_blocks ~trials:1 ~size ~precomputed_values ~logger ~verifier ~accounts_with_secret_keys ~path:output_folder
     )

let commands =
  [ ( "sequence", gen_sequence_of_blocks  )
  ]


let () =
Command.run
  (Command.group ~summary:"Dump blocks main commands"
     ~preserve_subcommand_order:() commands )

 
