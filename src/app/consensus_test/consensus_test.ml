open Core_kernel
open Async

module Block_file_output = struct
  type t = { height : int; previous_state_hash : string } [@@deriving to_yojson]
end

type select_outcome = Candidate_longer | Equal_length | Candidate_shorter

module type CONTEXT = sig
  val logger : Logger.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

let context (logger : Logger.t) (precomputed_values : Precomputed_values.t) :
    (module CONTEXT) =
  ( module struct
    let logger = logger

    let precomputed_values = precomputed_values

    let consensus_constants = precomputed_values.consensus_constants

    let constraint_constants = precomputed_values.constraint_constants
  end )

let generate_context ~logger ~runtime_config_file =
  let runtime_config_opt =
    Option.map runtime_config_file ~f:(fun file ->
        Yojson.Safe.from_file file |> Runtime_config.of_yojson
        |> Result.ok_or_failwith )
  in
  let runtime_config =
    Option.value ~default:Runtime_config.default runtime_config_opt
  in
  let proof_level = Genesis_constants.Proof_level.compiled in
  [%log info] "Generating context with given runtime config." ;
  match%map
    Genesis_ledger_helper.init_from_config_file ~logger
      ~proof_level:(Some proof_level) runtime_config
  with
  | Ok (precomputed_values, _) ->
      [%log info] "Initialization from config successful." ;
      context logger precomputed_values
  | Error err ->
      [%log fatal] "Failed initializing with configuration $config: $error"
        ~metadata:
          [ ("config", Runtime_config.to_yojson runtime_config)
          ; ("error", Error_json.error_to_yojson err)
          ] ;
      context logger
        { (Lazy.force Precomputed_values.for_unit_tests) with proof_level }

let read_directory ~logger dir_name =
  let blocks_in_dir dir =
    [%log info] "Reading directory: $dir" ~metadata:[ ("dir", `String dir) ] ;
    let%map blocks_array = Async.Sys.readdir dir in
    blocks_array
    |> Array.map ~f:(fun fname -> Filename.concat dir fname)
    |> Array.to_list
  in
  blocks_in_dir dir_name

let read_block_file blocks_filename =
  let parse_json_from_line line =
    match Yojson.Safe.from_string line with
    | json ->
        Some json
    | exception _ ->
        Format.printf "Warning: Could not parse JSON from line in file: %s\n"
          blocks_filename ;
        None
  in
  let block_of_json json =
    match Mina_block.Precomputed.of_yojson json with
    | Ok block ->
        Some block
    | Error err ->
        Format.printf "Warning: Could not read block: %s: %s\n" err
          blocks_filename ;
        None
  in
  let read_block_line line =
    match parse_json_from_line line with
    | Some json ->
        block_of_json json
    | None ->
        None
  in
  In_channel.with_file blocks_filename ~f:(fun blocks_file ->
      match In_channel.input_line blocks_file with
      | Some line ->
          read_block_line line
      | None ->
          Format.printf "Warning: File %s is empty\n" blocks_filename ;
          None )

let precomputed_block_to_block_file_output (block : Mina_block.Precomputed.t) =
  let open Yojson.Safe.Util in
  let block_json = Mina_block.Precomputed.to_yojson block in

  (* Extract desired fields *)
  let data = block_json |> member "data" in
  let protocol_state = data |> member "protocol_state" in
  let body = protocol_state |> member "body" in
  let consensus_state = body |> member "consensus_state" in
  let height =
    consensus_state |> member "blockchain_length" |> to_string |> int_of_string
  in
  let previous_state_hash =
    protocol_state |> member "previous_state_hash" |> to_string
  in
  { Block_file_output.height; previous_state_hash }

let write_blocks_to_output_dir ~current_chain ~output_dir =
  let sorted_output =
    List.map ~f:precomputed_block_to_block_file_output current_chain |> List.rev
  in
  let write_block_to_file i block : unit Deferred.t =
    let block_json_str =
      block |> Block_file_output.to_yojson |> Yojson.Safe.to_string
    in
    let output_file = sprintf "%s/block_%d.json" output_dir i in
    Writer.save output_file ~contents:block_json_str
  in
  let () =
    if not (Core.Sys.file_exists_exn output_dir) then Core.Unix.mkdir output_dir
  in
  Deferred.List.iteri sorted_output ~f:write_block_to_file

let compare_lengths candidate_length existing_length =
  if candidate_length > existing_length then Candidate_longer
  else if candidate_length = existing_length then Equal_length
  else Candidate_shorter

let run_select ~context (existing_block : Mina_block.Precomputed.t)
    (candidate_block : Mina_block.Precomputed.t) =
  let existing_consensus_state_with_hashes =
    { With_hash.hash =
        Mina_state.Protocol_state.hashes existing_block.protocol_state
    ; data =
        Mina_state.Protocol_state.consensus_state existing_block.protocol_state
    }
  in
  let candidate_consensus_state_with_hashes =
    { With_hash.hash =
        Mina_state.Protocol_state.hashes candidate_block.protocol_state
    ; data =
        Mina_state.Protocol_state.consensus_state candidate_block.protocol_state
    }
  in
  match
    Consensus.Hooks.select ~context
      ~existing:existing_consensus_state_with_hashes
      ~candidate:candidate_consensus_state_with_hashes
  with
  | `Take ->
      let candidate_length =
        Mina_state.Protocol_state.consensus_state candidate_block.protocol_state
        |> Consensus.Data.Consensus_state.blockchain_length
        |> Unsigned.UInt32.to_int
      in
      let existing_length =
        Mina_state.Protocol_state.consensus_state existing_block.protocol_state
        |> Consensus.Data.Consensus_state.blockchain_length
        |> Unsigned.UInt32.to_int
      in
      compare_lengths candidate_length existing_length
  | `Keep ->
      Candidate_shorter

let update_chain ~current_chain ~candidate_block ~select_outcome =
  match select_outcome with
  | Candidate_longer ->
      candidate_block :: current_chain
  | Equal_length -> (
      match current_chain with
      | _ :: rest_of_list ->
          candidate_block :: rest_of_list
      | [] ->
          current_chain )
  | Candidate_shorter ->
      current_chain

let process_precomputed_blocks ~context ~current_chain blocks =
  List.fold blocks ~init:current_chain ~f:(fun acc_chain candidate_block ->
      let existing_block = List.hd_exn acc_chain in
      let select_outcome = run_select ~context existing_block candidate_block in
      update_chain ~current_chain:acc_chain ~candidate_block ~select_outcome )

let extract_timestamp (block : Mina_block.Precomputed.t) =
  let bs = Mina_state.Protocol_state.blockchain_state block.protocol_state in
  Block_time.to_time_exn bs.timestamp

let main () ~blocks_dir ~output_dir ~runtime_config_file =
  let logger = Logger.create () in
  let%bind context = generate_context ~logger ~runtime_config_file in
  let%bind block_sorted_filenames = read_directory ~logger blocks_dir in
  let precomputed_blocks =
    block_sorted_filenames
    |> List.map ~f:read_block_file
    |> List.filter_map ~f:Fun.id
    |> List.sort ~compare:(fun a b ->
           Time.compare (extract_timestamp a) (extract_timestamp b) )
  in
  match precomputed_blocks with
  | [] ->
      failwith "No blocks found"
  | first_block :: precomputed_blocks ->
      [%log info] "Starting to process blocks"
        ~metadata:[ ("num_blocks", `Int (List.length precomputed_blocks)) ] ;
      let current_chain =
        process_precomputed_blocks ~current_chain:[ first_block ] ~context
          precomputed_blocks
      in
      [%log info] "Finished processing blocks" ;
      [%log info] "Starting to write blocks to output dir"
        ~metadata:[ ("output_dir", `String output_dir) ] ;
      let%bind () = write_blocks_to_output_dir ~current_chain ~output_dir in
      [%log info] "Finished writing blocks to output dir" ;
      return ()

let () =
  Command.(
    run
      (let open Let_syntax in
      async
        ~summary:
          "Run Mina PoS on a set of precomputed blocks and output the longest \
           chain"
        (let%map blocks_dir =
           Param.flag "--precomputed-dir" ~aliases:[ "-precomputed-dir" ]
             ~doc:"PATH Path of the blocks JSON data"
             Param.(required string)
         and output_dir =
           Param.flag "--output-dir" ~aliases:[ "-output-dir" ]
             ~doc:"PATH Path of the output directory"
             Param.(required string)
         and runtime_config_file =
           Param.flag "--config-file" ~aliases:[ "-config-file" ]
             Param.(optional string)
             ~doc:"PATH to the configuration file containing the genesis ledger"
         in
         main ~blocks_dir ~output_dir ~runtime_config_file )))
