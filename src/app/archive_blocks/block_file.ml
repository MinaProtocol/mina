(* block_file.ml -- write one block file to an archive database *)

open Core_kernel
open Async
open Archive_lib

module Format = struct
  type t = Precomputed | Extensional
end

(* Why a file was not added: what failed, and the error text. *)
type failure = { message : string; error : string }

let add_block ~of_yojson ~add_block_aux json =
  match of_yojson json with
  | Ok block -> (
      match%map add_block_aux block with
      | Ok () ->
          Ok ()
      | Error err ->
          Error
            { message = "Error when adding block"
            ; error = Caqti_error.show err
            } )
  | Error error ->
      return (Error { message = "Could not create block from JSON"; error })

(* Allows older-versioned blocks, kept at their own version. *)
let add_precomputed ~logger ~pool ~proof_cache_db ~genesis_constants
    ~constraint_constants =
  add_block ~of_yojson:Mina_block.Precomputed.Versioned.of_yojson
    ~add_block_aux:
      (Processor.add_block_aux_precomputed ~proof_cache_db ~genesis_constants
         ~constraint_constants ~pool ~delete_older_than:None ~logger )

(* Allows older-versioned blocks. *)
let add_extensional ~logger ~pool ~proof_cache_db ~genesis_constants =
  let of_yojson json =
    match Archive_lib.Extensional.Block.Stable.of_yojson_to_latest json with
    | Ok block ->
        Ok block
    | Error err ->
        Error (Error.to_string_hum err)
  in
  add_block ~of_yojson
    ~add_block_aux:
      (Processor.add_block_aux_extensional ~proof_cache_db ~genesis_constants
         ~logger ~pool ~delete_older_than:None
         ~signature_kind:Mina_signature_kind.t_DEPRECATED )

(* Adds the block in [file] to the database of [pool]. A block that cannot be
   read or added is an [Error] with the reason. *)
let add ~logger ~pool ~proof_cache_db ~genesis_constants ~constraint_constants
    ~format file =
  In_channel.with_file file ~f:(fun in_channel ->
      try
        let json = Yojson.Safe.from_channel in_channel in
        match (format : Format.t) with
        | Precomputed ->
            add_precomputed ~logger ~pool ~proof_cache_db ~genesis_constants
              ~constraint_constants json
        | Extensional ->
            add_extensional ~logger ~pool ~proof_cache_db ~genesis_constants
              json
      with
      | Yojson.Json_error error ->
          return (Error { message = "Could not parse JSON from file"; error })
      | exn ->
          (* should be unreachable *)
          return
            (Error
               { message = "Internal error when processing file"
               ; error = Exn.to_string exn
               } ) )
