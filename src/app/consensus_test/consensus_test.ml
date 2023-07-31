open Core_kernel
open Async

[@@@warning "-32"]

module BlockFileOutput = struct
  type t =
    { height : int; parent_state_hash : string; previous_state_hash : string }
  [@@deriving to_yojson]
end

type select_outcome = CandidateLonger | EqualLength | CandidateShorter

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

let context (logger : Logger.t) : (module CONTEXT) =
  ( module struct
    let logger = logger

    let proof_level = Genesis_constants.Proof_level.None

    let precomputed_values =
      { (Lazy.force Precomputed_values.for_unit_tests) with proof_level }

    let consensus_constants = precomputed_values.consensus_constants

    let constraint_constants = precomputed_values.constraint_constants
  end )

let read_directory dir_name =
  let extract_height_from_filename fname =
    let prefix_start = String.index_exn fname '-' + 1 in
    let suffix_start = String.index_from_exn fname prefix_start '-' in
    String.sub fname ~pos:prefix_start ~len:(suffix_start - prefix_start)
    |> int_of_string
  in
  let blocks_in_dir dir =
    let%map blocks_array = Async.Sys.readdir dir in
    Array.sort blocks_array ~compare:(fun a b ->
        Int.compare
          (extract_height_from_filename a)
          (extract_height_from_filename b) ) ;
    let blocks_array =
      Array.map ~f:(fun fname -> Filename.concat dir fname) blocks_array
    in
    Array.to_list blocks_array
  in
  blocks_in_dir dir_name

let read_block_file blocks_filename =
  let read_block_line line =
    match Yojson.Safe.from_string line |> Mina_block.Precomputed.of_yojson with
    | Ok block ->
        block
    | Error err ->
        failwithf "Could not read block: %s" err ()
  in
  let blocks_file = In_channel.create blocks_filename in
  match In_channel.input_line blocks_file with
  | Some line ->
      In_channel.close blocks_file ;
      return (read_block_line line)
  | None ->
      In_channel.close blocks_file ;
      failwithf "File %s is empty" blocks_filename ()

let precomputed_block_to_block_file_output (block : Mina_block.Precomputed.t) :
    BlockFileOutput.t =
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
  let parent_state_hash =
    protocol_state |> member "previous_state_hash" |> to_string
  in

  { BlockFileOutput.height
  ; BlockFileOutput.parent_state_hash
  ; BlockFileOutput.previous_state_hash = parent_state_hash
  }

let compare_lengths candidate_length existing_length =
  if candidate_length > existing_length then CandidateLonger
  else if candidate_length = existing_length then EqualLength
  else CandidateShorter

let update_chain ~current_chain ~candidate_block ~select_outcome =
  match select_outcome with
  | CandidateLonger ->
      candidate_block :: !current_chain
  | EqualLength -> (
      match !current_chain with
      | _ :: rest_of_list ->
          candidate_block :: rest_of_list
      | [] ->
          !current_chain )
  | CandidateShorter ->
      !current_chain

let run_select ~context:(module Context : CONTEXT)
    (existing_block : Mina_block.Precomputed.t)
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
    Consensus.Hooks.select
      ~context:(module Context)
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
      CandidateShorter

let process_precomputed_blocks ~context ~current_chain blocks =
  let%bind () =
    Deferred.List.iter blocks ~f:(fun candidate_block ->
        let existing_block = List.hd_exn !current_chain in
        let select_outcome =
          run_select ~context existing_block candidate_block
        in
        current_chain :=
          update_chain ~current_chain ~candidate_block ~select_outcome ;
        return () )
  in
  return ()

let write_blocks_to_output_dir ~current_chain ~output_dir =
  let sorted_output =
    List.map ~f:precomputed_block_to_block_file_output !current_chain
    |> List.rev
  in
  let write_block_to_file (i : int) (block : BlockFileOutput.t) :
      unit Deferred.t =
    let block_json_str =
      block |> BlockFileOutput.to_yojson |> Yojson.Safe.to_string
    in
    let output_file = sprintf "%s/block_%d.json" output_dir i in
    Writer.save output_file ~contents:block_json_str
  in
  let%bind () =
    Deferred.List.iteri sorted_output ~f:(fun i block ->
        let%bind () = write_block_to_file i block in
        return () )
  in
  return ()

let main () ~blocks_dir ~output_dir =
  let logger = Logger.create () in
  let current_chain : Mina_block.Precomputed.t list ref = ref [] in

  [%log info] "Starting to read blocks dir"
    ~metadata:[ ("blocks_dir", `String blocks_dir) ] ;
  let%bind block_sorted_filenames = read_directory blocks_dir in
  let%bind precomputed_blocks =
    Deferred.List.map block_sorted_filenames ~f:(fun json ->
        read_block_file json )
  in
  [%log info] "Finished reading blocks dir" ;
  let context = context logger in

  match precomputed_blocks with
  | [] ->
      failwith "No blocks found"
  | first_block :: precomputed_blocks ->
      [%log info] "Starting to process blocks"
        ~metadata:[ ("num_blocks", `Int (List.length precomputed_blocks)) ] ;
      current_chain := [ first_block ] ;
      let%bind () =
        process_precomputed_blocks ~context ~current_chain precomputed_blocks
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
      async ~summary:"TODO"
        (let%map blocks_dir =
           Param.flag "--blocks-dir" ~doc:"STRING Path of the blocks JSON data"
             Param.(required string)
         and output_dir =
           Param.flag "--output-dir" ~doc:"STRING Path of the output directory"
             Param.(required string)
         in
         main ~blocks_dir ~output_dir )))
