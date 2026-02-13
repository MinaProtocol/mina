open Core
open Async

let blockchain_of_breadcrumb breadcrumb =
  let block = Frontier_base.Breadcrumb.block breadcrumb in
  let header = Mina_block.header block in
  Blockchain_snark.Blockchain.create
    ~state:(Mina_block.Header.protocol_state header)
    ~proof:(Mina_block.Header.protocol_state_proof header)

let load_and_initialize_config ~logger ~config_file ~genesis_dir =
  let%bind runtime_config_json =
    Genesis_ledger_helper.load_config_json config_file >>| Or_error.ok_exn
  in
  let runtime_config =
    Runtime_config.of_yojson runtime_config_json
    |> Result.map_error ~f:Error.of_string
    |> Or_error.ok_exn
  in
  let genesis_constants = Genesis_constants.Compiled.genesis_constants in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let proof_level = Genesis_constants.Compiled.proof_level in
  Genesis_ledger_helper.init_from_config_file ~genesis_constants
    ~constraint_constants ~logger ~proof_level ~cli_proof_level:None
    ~genesis_dir runtime_config
  >>| Or_error.ok_exn

let run ~logger ~keypair ~config_file ~num_blocks ~genesis_dir ~state_dir =
  let%bind precomputed_values =
    load_and_initialize_config ~logger ~config_file ~genesis_dir
  in
  [%log info] "Creating genesis breadcrumb (this involves proving)" ;
  let%bind genesis_breadcrumb =
    Block_stepper.create_genesis_breadcrumb ~logger ~precomputed_values ()
  in
  [%log info] "Genesis breadcrumb created" ;
  let start = Block_stepper.start_state_of_genesis genesis_breadcrumb in
  [%log info] "Initializing block stepper" ;
  let%bind stepper =
    Block_stepper.create ~precomputed_values ~keypair ~start ~logger ~state_dir
      ()
  in
  let verifier = Block_stepper.verifier stepper in
  [%log info] "Verifying genesis block proof" ;
  let genesis_blockchain = blockchain_of_breadcrumb genesis_breadcrumb in
  let%bind genesis_result =
    Verifier.verify_blockchain_snarks verifier [ genesis_blockchain ]
  in
  ( match genesis_result with
  | Ok (Ok ()) ->
      [%log info] "Genesis block proof verification: PASSED"
  | Ok (Error e) ->
      [%log error] "Genesis block proof verification: FAILED - %s"
        (Error.to_string_hum e) ;
      failwith "Genesis block proof verification failed"
  | Error e ->
      [%log error]
        "Genesis block proof verification: ERROR (verifier issue) - %s"
        (Error.to_string_hum e) ;
      failwith "Genesis block proof verification error" ) ;
  [%log info] "Generating and verifying %d blocks" num_blocks ;
  let%map _final_stepper =
    Deferred.List.foldi (List.init num_blocks ~f:Fn.id) ~init:stepper
      ~f:(fun i stepper _block_index ->
        let block_num = i + 1 in
        [%log info] "Stepping block %d/%d" block_num num_blocks ;
        let%bind breadcrumb, stepper =
          Block_stepper.step stepper ~transactions:Sequence.empty
        in
        [%log info] "Block %d produced, verifying proof" block_num ;
        let blockchain = blockchain_of_breadcrumb breadcrumb in
        let%map result =
          Verifier.verify_blockchain_snarks verifier [ blockchain ]
        in
        ( match result with
        | Ok (Ok ()) ->
            [%log info] "Block %d/%d proof verification: PASSED" block_num
              num_blocks
        | Ok (Error e) ->
            [%log error] "Block %d/%d proof verification: FAILED - %s" block_num
              num_blocks (Error.to_string_hum e) ;
            failwithf "Block %d proof verification failed" block_num ()
        | Error e ->
            [%log error]
              "Block %d/%d proof verification: ERROR (verifier issue) - %s"
              block_num num_blocks (Error.to_string_hum e) ;
            failwithf "Block %d proof verification error" block_num () ) ;
        stepper )
  in
  [%log info] "All %d blocks passed proof verification" num_blocks

let command =
  Command.async
    ~summary:
      "Generate blocks using the block stepper and verify each block's SNARK \
       proof"
    (let open Command.Let_syntax in
    let%map_open config_file =
      flag "--config-file" ~doc:"FILE Path to the runtime configuration file"
        (required string)
    and privkey_path = Cli_lib.Flag.privkey_read_path
    and num_blocks =
      flag "--num-blocks"
        ~doc:"NUM Number of blocks to generate and verify (default: 3)"
        (optional_with_default 3 int)
    and state_dir_flag =
      flag "--state-dir"
        ~doc:
          "DIR Directory for all stepper state (verifier, epoch ledger, \
           internal tracing). Created if absent. Defaults to current \
           directory."
        (optional string)
    and genesis_ledger_dir =
      flag "--genesis-ledger-dir"
        ~doc:
          "DIR Directory containing genesis ledger tarballs (default: \
           <state-dir>/genesis)"
        (optional string)
    in
    Cli_lib.Exceptions.handle_nicely
    @@ fun () ->
    let open Deferred.Let_syntax in
    let logger = Logger.create ~id:Logger.Logger_id.mina () in
    let%bind state_dir =
      match state_dir_flag with Some dir -> return dir | None -> Sys.getcwd ()
    in
    let genesis_dir =
      match genesis_ledger_dir with
      | Some dir ->
          dir
      | None ->
          Filename.concat state_dir "genesis"
    in
    let%bind () = Unix.mkdir ~p:() state_dir in
    [%log info] "Starting block stepper verification test"
      ~metadata:
        [ ("config_file", `String config_file)
        ; ("num_blocks", `Int num_blocks)
        ] ;
    let log_processor =
      Logger.Processor.pretty ~log_level:Info
        ~config:
          { Interpolator_lib.Interpolator.mode = After
          ; max_interpolation_length = 50
          ; pretty_print = true
          }
    in
    Logger.Consumer_registry.register ~commit_id:Mina_version.commit_id
      ~id:Logger.Logger_id.mina ~processor:log_processor
      ~transport:(Logger.Transport.stdout ())
      () ;
    let internal_tracing_directory =
      Filename.concat state_dir "internal-tracing"
    in
    Logger.Consumer_registry.register ~commit_id:"" ~id:Logger.Logger_id.mina
      ~processor:Internal_tracing.For_logger.processor
      ~transport:
        (Internal_tracing.For_logger.json_lines_rotate_transport
           ~directory:internal_tracing_directory () )
      () ;
    let%bind () = Internal_tracing.toggle ~commit_id:"" ~logger `Enabled in
    [%log info] "Loading keypair from %s" privkey_path ;
    let%bind keypair =
      Secrets.Keypair.Terminal_stdin.read_exn ~which:"Mina keypair" privkey_path
    in
    Parallel.init_master () ;
    run ~logger ~keypair ~config_file ~num_blocks ~genesis_dir ~state_dir)

let () = Command.run command
