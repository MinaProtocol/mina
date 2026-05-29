open Core
open Async
open Signature_lib
module Global_slot_since_hard_fork = Mina_numbers.Global_slot_since_hard_fork

let read_rss_kb () =
  try
    let ic = In_channel.create "/proc/self/status" in
    let rec find_vmrss () =
      match In_channel.input_line ic with
      | None ->
          None
      | Some line -> (
          match
            Option.try_with (fun () -> Scanf.sscanf line "VmRSS: %f" Fn.id)
          with
          | Some kb ->
              Some kb
          | None ->
              find_vmrss () )
    in
    let result = find_vmrss () in
    In_channel.close ic ; result
  with _ -> None

let ensure_rss_within_limit ~max_rss_kb =
  match read_rss_kb () with
  | Some rss_kb when Float.(rss_kb > max_rss_kb) ->
      eprintf "vrf-evaluation-stream exceeded RSS limit: %.0f kB > %.0f kB\n%!"
        rss_kb max_rss_kb ;
      Core.exit 1
  | Some _ | None ->
      ()

let output_slot_won_json ~consensus_constants
    ({ Consensus.Data.Slot_won.delegator = delegator, delegator_index
     ; producer
     ; global_slot
     ; global_slot_since_genesis
     ; vrf_result
     } :
      Consensus.Data.Slot_won.t ) =
  let consensus_time =
    Consensus.Data.Consensus_time.of_global_slot ~constants:consensus_constants
      global_slot
  in
  let epoch =
    Consensus.Data.Consensus_time.epoch consensus_time |> Unsigned.UInt32.to_int
  in
  let slot =
    Consensus.Data.Consensus_time.slot consensus_time |> Unsigned.UInt32.to_int
  in
  let producer_public_key = Public_key.compress producer.Keypair.public_key in
  let json =
    `Assoc
      [ ("epoch", `Int epoch)
      ; ("slot", `Int slot)
      ; ( "global_slot_since_hard_fork"
        , Global_slot_since_hard_fork.to_yojson global_slot )
      ; ( "global_slot_since_genesis"
        , Mina_numbers.Global_slot_since_genesis.to_yojson
            global_slot_since_genesis )
      ; ("delegator", Public_key.Compressed.to_yojson delegator)
      ; ("delegator_index", Mina_base.Account.Index.to_yojson delegator_index)
      ; ("producer", Public_key.Compressed.to_yojson producer_public_key)
      ; ("vrf_result", `String (Snark_params.Tick.Field.to_string vrf_result))
      ]
  in
  printf "%s\n%!" (Yojson.Safe.to_string json)

let wait_until_epoch_complete ~max_rss_kb ~poll_interval ~consensus_constants
    evaluator =
  let rec loop ~saw_running () =
    ensure_rss_within_limit ~max_rss_kb ;
    let%bind { Vrf_evaluator.Vrf_evaluation_result.slots_won; evaluator_status }
        =
      Vrf_evaluator.Single_process.slots_won_so_far evaluator
    in
    List.iter slots_won ~f:(output_slot_won_json ~consensus_constants) ;
    match evaluator_status with
    | Vrf_evaluator.Evaluator_status.Completed ->
        if saw_running then Deferred.unit
        else
          let%bind () = after poll_interval in
          loop ~saw_running ()
    | Vrf_evaluator.Evaluator_status.At _ ->
        let%bind () = after poll_interval in
        loop ~saw_running:true ()
  in
  loop ~saw_running:false ()

let config_from_file ~logger config_file =
  let open Deferred.Or_error.Let_syntax in
  let%bind config_json = Genesis_ledger_helper.load_config_json config_file in
  let%bind config_json =
    Genesis_ledger_helper.upgrade_old_config ~logger config_file config_json
    |> Deferred.map ~f:Or_error.return
  in
  let%map runtime_config =
    Runtime_config.of_yojson config_json
    |> Result.map_error ~f:Error.of_string
    |> Deferred.return
  in
  runtime_config

let load_precomputed_values ~logger ~config_file ~genesis_dir =
  let genesis_constants = Genesis_constants.Compiled.genesis_constants in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let proof_level = Genesis_constants.Compiled.proof_level in
  let open Deferred.Or_error.Let_syntax in
  let%bind runtime_config = config_from_file ~logger config_file in
  let%map precomputed_values =
    Genesis_ledger_helper.init_from_config_file ~cli_proof_level:None
      ~genesis_dir ~logger ~genesis_constants ~constraint_constants ~proof_level
      runtime_config
  in
  (precomputed_values, runtime_config)

let epoch_zero_data ~consensus_state ~local_state =
  let staking_epoch_data =
    Consensus.Data.Consensus_state.staking_epoch_data consensus_state
  in
  Consensus.Data.Epoch_data_for_vrf.
    { epoch_ledger = staking_epoch_data.ledger
    ; epoch_seed = staking_epoch_data.seed
    ; epoch = Consensus.Data.Consensus_state.curr_epoch consensus_state
    ; global_slot =
        Consensus.Data.Consensus_state.curr_global_slot consensus_state
    ; global_slot_since_genesis =
        Consensus.Data.Consensus_state.global_slot_since_genesis consensus_state
    ; delegatee_table =
        Consensus.Data.Local_state.current_epoch_delegatee_table ~local_state
    }

let first_slot_of_second_epoch ~consensus_constants =
  let rec go consensus_time =
    let epoch = Consensus.Data.Consensus_time.epoch consensus_time in
    let slot = Consensus.Data.Consensus_time.slot consensus_time in
    if
      Unsigned.UInt32.equal epoch Unsigned.UInt32.one
      && Unsigned.UInt32.equal slot Unsigned.UInt32.zero
    then consensus_time
    else go (Consensus.Data.Consensus_time.succ consensus_time)
  in
  go (Consensus.Data.Consensus_time.zero ~constants:consensus_constants)

let epoch_one_data ~logger ~consensus_constants ~consensus_state ~local_state =
  let now =
    first_slot_of_second_epoch ~consensus_constants
    |> Consensus.Data.Consensus_time.start_time ~constants:consensus_constants
    |> Block_time.to_span_since_epoch |> Block_time.Span.to_ms
  in
  fst
    (Consensus.Hooks.get_epoch_data_for_vrf ~constants:consensus_constants now
       consensus_state ~local_state ~logger )

let run ~config_file ~block_producer_key ~config_directory ~log_file ~max_rss_gb
    () =
  let conf_dir =
    Option.value config_directory ~default:(Filename.dirname config_file)
  in
  let log_dir = Filename.dirname log_file in
  let log_filename = Filename.basename log_file in
  Core.Unix.mkdir_p ~perm:0o755 conf_dir ;
  Core.Unix.mkdir_p ~perm:0o755 log_dir ;
  Vrf_evaluator.register_file_logger ~conf_dir:log_dir
    ~commit_id:Mina_version.commit_id ~log_filename ;
  let logger = Logger.create () in
  let max_rss_kb = max_rss_gb *. 1024. *. 1024. in
  let poll_interval = Time.Span.of_ms 100. in
  let genesis_dir = Filename.dirname config_file in
  let%bind precomputed_values, _runtime_config =
    load_precomputed_values ~logger ~config_file ~genesis_dir
    >>| Or_error.ok_exn
  in
  let%bind block_producer_keypair =
    Secrets.Keypair.Terminal_stdin.read_exn ~should_prompt_user:false
      ~which:"block producer keypair" block_producer_key
  in
  let block_production_keys =
    Public_key.compress block_producer_keypair.public_key
    |> Public_key.Compressed.Set.singleton
  in
  let epoch_ledger_location = conf_dir ^/ "epoch_ledger" in
  Core.Unix.mkdir_p ~perm:0o755 epoch_ledger_location ;
  let module Context = struct
    let logger = logger

    let constraint_constants = precomputed_values.constraint_constants

    let consensus_constants = precomputed_values.consensus_constants
  end in
  let consensus_local_state =
    Consensus.Data.Local_state.create
      ~context:(module Context)
      ~genesis_ledger:precomputed_values.genesis_ledger
      ~genesis_epoch_data:precomputed_values.genesis_epoch_data
      ~epoch_ledger_location
      ~genesis_state_hash:
        precomputed_values.protocol_state_with_hashes.hash.state_hash
      ~epoch_ledger_backing_type:Mina_ledger.Root.Config.Stable_db
      block_production_keys
  in
  let keypairs =
    Keypair.And_compressed_pk.Set.singleton
      ( block_producer_keypair
      , Public_key.compress block_producer_keypair.public_key )
  in
  let%bind evaluator =
    Vrf_evaluator.Single_process.create ~register_logger:false
      ~constraint_constants:precomputed_values.constraint_constants
      ~consensus_constants:precomputed_values.consensus_constants ~conf_dir
      ~logger ~keypairs ~commit_id:Mina_version.commit_id
  in
  let consensus_state =
    Precomputed_values.genesis_state precomputed_values
    |> Mina_state.Protocol_state.consensus_state
  in
  let epoch_zero_data =
    epoch_zero_data ~consensus_state ~local_state:consensus_local_state
  in
  let epoch_one_data =
    epoch_one_data ~logger
      ~consensus_constants:precomputed_values.consensus_constants
      ~consensus_state ~local_state:consensus_local_state
  in
  let%bind () =
    Vrf_evaluator.Single_process.set_new_epoch_state evaluator
      ~epoch_data_for_vrf:epoch_zero_data
  in
  let%bind () =
    wait_until_epoch_complete ~max_rss_kb ~poll_interval
      ~consensus_constants:precomputed_values.consensus_constants evaluator
  in
  let%bind () =
    Vrf_evaluator.Single_process.set_new_epoch_state evaluator
      ~epoch_data_for_vrf:epoch_one_data
  in
  wait_until_epoch_complete ~max_rss_kb ~poll_interval
    ~consensus_constants:precomputed_values.consensus_constants evaluator

let command =
  let open Command.Let_syntax in
  Command.async
    ~summary:
      "Run VRF slot discovery for the first two epochs in a single process"
    [%map_open
      let config_file =
        Command.Param.flag "--config-file" ~aliases:[ "config-file" ]
          Command.Param.(required string)
          ~doc:"FILE Runtime config JSON to load"
      and block_producer_key =
        Command.Param.flag "--block-producer-key"
          ~aliases:[ "block-producer-key" ]
          Command.Param.(required string)
          ~doc:"FILE Block producer private key file"
      and config_directory =
        Command.Param.flag "--config-directory" ~aliases:[ "config-directory" ]
          Command.Param.(optional string)
          ~doc:
            "DIR Working directory for logs and epoch ledger data (default: \
             directory containing --config-file)"
      and log_file =
        Command.Param.flag "--log-file" ~aliases:[ "log-file" ]
          Command.Param.(
            optional_with_default "mina-vrf-evaluation-stream.log" string)
          ~doc:"FILE Log file path"
      and max_rss_gb =
        Command.Param.flag "--max-rss-gb" ~aliases:[ "max-rss-gb" ]
          Command.Param.(optional_with_default 2.0 float)
          ~doc:"FLOAT Exit once process RSS exceeds this many GiB"
      in
      run ~config_file ~block_producer_key ~config_directory ~log_file
        ~max_rss_gb]
