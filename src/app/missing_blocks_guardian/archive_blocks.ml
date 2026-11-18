(* archive_blocks.ml -- write block files to the archive database *)

open Core
open Async
module Block_file = Archive_blocks_lib.Block_file

let block_file_format : Config.Block_format.t -> Block_file.Format.t = function
  | Precomputed ->
      Precomputed
  | Extensional ->
      Extensional

(* Returns the function that adds a block file to the database of [pool]. A
   block that cannot be added is an [Error] with the reason. *)
let add_block ~logger ~pool ~format =
  let (module G) = Genesis_constants.profiled () in
  let proof_cache_db = Proof_cache_tag.create_identity_db () in
  let format = block_file_format format in
  fun file ->
    let failed error =
      Error
        (sprintf "Could not add %s: %s. The database remains unhealthy." file
           error )
    in
    match%map
      Monitor.try_with_or_error (fun () ->
          Block_file.add ~logger ~pool ~proof_cache_db
            ~genesis_constants:G.genesis_constants
            ~constraint_constants:G.constraint_constants ~format file )
    with
    | Ok (Ok ()) ->
        Ok ()
    | Ok (Error { message; error }) ->
        failed (message ^ ": " ^ error)
    | Error err ->
        failed (Error.to_string_hum err)
