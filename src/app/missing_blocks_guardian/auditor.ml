(* auditor.ml -- find the next missing block with the audit of the archive *)

open Core
open Async
module Audit = Missing_blocks_auditor_lib.Audit

type missing_parent = { hash : string; height : int } [@@deriving equal]

(* The first block in [missing_blocks]. *)
let first_missing_parent (missing_blocks : Audit.missing_block list) =
  Option.map (List.hd missing_blocks) ~f:(fun missing ->
      { hash = missing.parent_hash; height = missing.parent_height } )

(* Finds the missing blocks in the database of [pool] and returns the first
   missing parent. Only this check of the audit runs: the other problems of
   the archive are not for the guardian to repair, and their queries would
   run again after each restored block. A check that cannot finish is an
   [Error] with the reason. *)
let check ~logger ~pool =
  match%map Audit.missing_blocks ~logger ~pool with
  | Ok missing_blocks ->
      Ok (first_missing_parent missing_blocks)
  | Error { message; error } ->
      Error (sprintf "The audit failed: %s: %s" message error)
