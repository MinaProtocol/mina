(**
  Steps that this program needs to accomplish.

  1. Read in all block data in a list ordered by timestamp

  2. For each block, check if the block is valid

  3. If the block is valid, convert it into an OCaml block type

  4. Initialize any PoS data structures

  5. Run the PoS selection algorithm on the blocks

  6. Print out the results
*)

open Core_kernel
open Async

module type CONTEXT = sig
  val logger : Logger.t

  val _precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

let context (logger : Logger.t) : (module CONTEXT) =
  ( module struct
    let logger = logger

    let proof_level = Genesis_constants.Proof_level.None

    let _precomputed_values =
      { (Lazy.force Precomputed_values.for_unit_tests) with proof_level }

    let consensus_constants = _precomputed_values.consensus_constants

    let constraint_constants = _precomputed_values.constraint_constants
  end )

let read_directory dir_name =
  let extract_height_from_filename fname =
    (*TODO: replace this with generic network *)
    let prefix = "berkeley-" in
    let prefix_len = String.length prefix in
    match String.index_from fname (String.length prefix) '-' with
    | None ->
        failwith "Could not find block height number in filename"
    | Some suffix_start ->
        let number_str =
          String.sub fname ~pos:prefix_len ~len:(suffix_start - prefix_len)
        in
        int_of_string number_str
  in
  let blocks_in_dir dir =
    let%map blocks_array = Async.Sys.readdir dir in
    Array.sort blocks_array ~compare:(fun a b ->
        Int.compare
          (extract_height_from_filename a)
          (extract_height_from_filename b) ) ;
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
  let blocks =
    Sequence.unfold ~init:(In_channel.create blocks_filename)
      ~f:(fun blocks_file ->
        match In_channel.input_line blocks_file with
        | Some line ->
            Some (read_block_line line, blocks_file)
        | None ->
            In_channel.close blocks_file ;
            None )
  in
  return blocks

let run_select ~context:(module Context : CONTEXT)
    (block : Mina_block.Precomputed.t) =
  let protocol_state_hashes =
    Mina_state.Protocol_state.hashes block.protocol_state
  in
  let consensus_state_with_hashes =
    { With_hash.hash = protocol_state_hashes
    ; data = Mina_state.Protocol_state.consensus_state block.protocol_state
    }
  in
  let _t =
    Consensus.Hooks.select
      ~context:(module Context)
      ~existing:consensus_state_with_hashes
      ~candidate:consensus_state_with_hashes
  in
  return ()

let process_block ~context precomputed_blocks =
  match Sequence.next precomputed_blocks with
  | Some (precomputed_block, _precomputed_blocks) ->
      let%bind () = run_select ~context precomputed_block in
      return ()
  | None ->
      return ()

let process_precomputed_blocks ~context blocks =
  let%bind () =
    Deferred.List.iter blocks ~f:(fun block ->
        let%bind () = process_block ~context block in
        return () )
  in
  return ()

let json_to_precomputed json_blocks =
  Deferred.List.map json_blocks ~f:(fun json -> read_block_file json)

let main () ~blocks_dir =
  let logger = Logger.create () in
  let context = context logger in

  [%log info] "Starting to read blocks dir"
    ~metadata:[ ("blocks_dir", `String blocks_dir) ] ;
  let%bind json_blocks = read_directory blocks_dir in
  let%bind blocks = json_to_precomputed json_blocks in
  [%log info] "Finished reading blocks dir" ;

  let%bind () = process_precomputed_blocks ~context blocks in

  return ()

let () =
  Command.(
    run
      (let open Let_syntax in
      async ~summary:"TODO"
        (let%map blocks_dir =
           Param.flag "--blocks-dir" ~doc:"STRING Path of the blocks JSON data"
             Param.(required string)
         in
         main ~blocks_dir )))
