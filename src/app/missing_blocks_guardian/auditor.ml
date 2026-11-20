(* auditor.ml -- find the next missing block with the audit of the archive *)

open Core
open Async
module Audit = Missing_blocks_auditor_lib.Audit

type missing_parent = { hash : string; height : int } [@@deriving equal]

(* The first block that the audit reports as missing. Other problems of the
   audit are not for the guardian to repair. *)
let first_missing_parent (report : Audit.report) =
  Option.map (List.hd report.missing_blocks) ~f:(fun missing ->
      { hash = missing.parent_hash; height = missing.parent_height } )

(* Audits the database of [pool] and returns the first missing parent. An
   audit that cannot finish is an [Error] with the reason. *)
let check ~logger ~pool =
  match%map Audit.run ~logger ~pool with
  | Ok report ->
      Ok (first_missing_parent report)
  | Error { message; error } ->
      Error (sprintf "The audit failed: %s: %s" message error)
