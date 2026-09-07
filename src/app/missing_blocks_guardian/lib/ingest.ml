(* ingest.ml -- write one downloaded block into the archive database.

   The bash guardian shelled out to [mina-archive-blocks] and read its exit
   status.  [mina-archive-blocks] exits 0 even when every block it was given
   failed to be added, so the guardian treated a failed ingest as a success and
   looped forever on the same missing block.  Calling the archive processor
   here gives us the actual [Caqti_error] for each block. *)

open Core
open Async
open Archive_lib

type format = Precomputed | Extensional

let format_to_string = function
  | Precomputed ->
      "precomputed"
  | Extensional ->
      "extensional"

let format_of_string = function
  | "precomputed" ->
      Ok Precomputed
  | "extensional" ->
      Ok Extensional
  | other ->
      Or_error.errorf
        "unknown block format %S. Supported formats are precomputed and \
         extensional"
        other

(** Decode the JSON of a block file and write the block to the archive.  Older
    block versions are accepted, exactly as [mina-archive-blocks] accepts them.
    [where] is the location the JSON came from, used in error messages. *)
let add ~format ~pool ~logger ~genesis_constants ~constraint_constants
    ~proof_cache_db ~json ~where =
  let of_yojson_error err =
    Deferred.return
      (Or_error.errorf "%s does not decode as a %s block: %s" where
         (format_to_string format) err )
  in
  let wrap_caqti = function
    | Ok () ->
        Ok ()
    | Error err ->
        Or_error.errorf "the archive rejected the block from %s: %s" where
          (Caqti_error.show err)
  in
  match format with
  | Precomputed -> (
      match Mina_block.Precomputed.Stable.of_yojson_to_latest json with
      | Error err ->
          of_yojson_error (Error.to_string_hum err)
      | Ok block ->
          let%map result =
            Processor.add_block_aux_precomputed ~proof_cache_db
              ~genesis_constants ~constraint_constants ~pool
              ~delete_older_than:None ~logger block
          in
          wrap_caqti result )
  | Extensional -> (
      match Extensional.Block.Stable.of_yojson_to_latest json with
      | Error err ->
          of_yojson_error (Error.to_string_hum err)
      | Ok block ->
          let%map result =
            Processor.add_block_aux_extensional ~proof_cache_db
              ~genesis_constants ~logger ~pool ~delete_older_than:None
              ~signature_kind:Mina_signature_kind.t_DEPRECATED block
          in
          wrap_caqti result )

let%test_module "block format" =
  ( module struct
    let%test "known formats round-trip" =
      List.for_all [ Precomputed; Extensional ] ~f:(fun f ->
          match format_of_string (format_to_string f) with
          | Ok f' ->
              String.equal (format_to_string f) (format_to_string f')
          | Error _ ->
              false )

    let%test "an unknown format is rejected" =
      Or_error.is_error (format_of_string "extensionall")
  end )
