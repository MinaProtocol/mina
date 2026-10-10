(* block_json.ml -- add a block, given as the JSON of a block file, to the
   archive. Older block versions are accepted. *)

open Core_kernel
open Async

type format = Precomputed | Extensional [@@deriving equal]

let format_to_string = function
  | Precomputed ->
      "precomputed"
  | Extensional ->
      "extensional"

let format_of_string s =
  match String.lowercase s with
  | "precomputed" ->
      Ok Precomputed
  | "extensional" ->
      Ok Extensional
  | _ ->
      Or_error.errorf
        "unknown block format %S. Supported formats are precomputed and \
         extensional"
        s

type error =
  | Decode of string  (** the JSON is not a block of that format *)
  | Rejected of Caqti_error.t  (** the archive refused the block *)

let add_decoded ~decode ~add json =
  match decode json with
  | Error err ->
      return (Error (Decode (Error.to_string_hum err)))
  | Ok block ->
      Deferred.Result.map_error (add block) ~f:(fun err -> Rejected err)

let add ~format ~proof_cache_db ~genesis_constants ~constraint_constants ~pool
    ~logger json =
  match format with
  | Precomputed ->
      add_decoded json ~decode:Mina_block.Precomputed.Stable.of_yojson_to_latest
        ~add:
          (Processor.add_block_aux_precomputed ~proof_cache_db
             ~genesis_constants ~constraint_constants ~pool
             ~delete_older_than:None ~logger )
  | Extensional ->
      add_decoded json ~decode:Extensional.Block.Stable.of_yojson_to_latest
        ~add:
          (Processor.add_block_aux_extensional ~proof_cache_db
             ~genesis_constants ~logger ~pool ~delete_older_than:None
             ~signature_kind:Mina_signature_kind.t_DEPRECATED )

let%test "known formats round-trip" =
  List.for_all [ Precomputed; Extensional ] ~f:(fun format ->
      match format_of_string (format_to_string format) with
      | Ok parsed ->
          equal_format format parsed
      | Error _ ->
          false )

let%test "an unknown format is rejected" =
  Or_error.is_error (format_of_string "extensionall")
