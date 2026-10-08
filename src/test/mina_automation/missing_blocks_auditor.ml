(**
Module to run the missing_blocks_auditor app, which reports the gaps in a
given archive database. Its exit code has one bit per kind of problem; see
[src/app/missing_blocks_auditor/README.md].
*)

open Core

module Paths = struct
  let dune_name = "src/app/missing_blocks_auditor/missing_blocks_auditor.exe"

  let official_name = "mina-missing-blocks-auditor"
end

module Executor = Executor.Make (Paths)

type t = Executor.t

let default = Executor.default

let args ~archive_uri ~min_height =
  [ "--archive-uri"; Uri.to_string archive_uri ]
  @ Option.value_map min_height ~default:[] ~f:(fun height ->
        [ "--min-height"; Int.to_string height ] )

let run_capturing ?min_height t ~archive_uri =
  let%bind.Async_kernel.Deferred _prog, process =
    Executor.run_in_background t ~args:(args ~archive_uri ~min_height) ()
  in
  Utils.collect_outcome process

(** The exit-code bit set for blocks with no parent in the archive. *)
let missing_blocks_bit = 1
