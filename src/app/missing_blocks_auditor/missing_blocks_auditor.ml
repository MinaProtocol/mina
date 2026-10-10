(* missing_blocks_auditor.ml -- report the gaps in an archive database.

   The audit is [Missing_blocks_auditor_lib.Audit], shared with the missing
   blocks guardian. This executable keeps its own command line and exit code,
   which deployments script against. *)

open Core
open Async
open Missing_blocks_auditor_lib

(* Bits of the exit code, one per kind of problem; 0 means healthy. A failure
   to read the archive at all exits 1. *)
module Exit_code = struct
  let missing_blocks = 0

  let pending_blocks = 1

  let chain_length = 2

  let chain_status = 3

  (* The archive has no block, no canonical block, or no block the chain
     starts from: the audit cannot place the chain, which this exit code has
     always reported as bit 0. *)
  let bit : Audit.Problem.t -> int = function
    | Missing_blocks _
    | Empty_archive
    | No_genesis_block _
    | No_fork_block _
    | No_canonical_blocks ->
        missing_blocks
    | Pending_below_canonical _ ->
        pending_blocks
    | Canonical_chain_incomplete _ ->
        chain_length
    | Invalid_chain_status _ ->
        chain_status

  let of_problems problems =
    List.fold problems ~init:0 ~f:(fun code problem ->
        code lor (1 lsl bit problem) )
end

let main ~archive_uri ~min_height () =
  let logger = Logger.create () in
  match Mina_caqti.connect_pool ~max_size:128 (Uri.of_string archive_uri) with
  | Error e ->
      [%log fatal]
        ~metadata:[ ("error", `String (Caqti_error.show e)) ]
        "Failed to create a Caqti pool for Postgresql" ;
      exit 1
  | Ok pool -> (
      [%log info] "Successfully created Caqti pool for Postgresql" ;
      match%bind Audit.report pool ~min_height with
      | Error error ->
          [%log error] "Error auditing the archive database"
            ~metadata:[ ("error", `String (Error.to_string_hum error)) ] ;
          exit 1
      | Ok report ->
          Audit.log_report ~logger report ;
          exit (Exit_code.of_problems (Audit.Report.problems report)) )

let () =
  Command.(
    run
      (let open Let_syntax in
      Command.async
        ~summary:"Report state hashes of blocks missing from archive database"
        (let%map archive_uri =
           Param.flag "--archive-uri"
             ~doc:
               "URI URI for connecting to the archive database (e.g., \
                postgres://$USER@localhost:5432/archiver)"
             Param.(required string)
         and min_height =
           Param.flag "--min-height"
             ~doc:
               "HEIGHT Height of the earliest block this archive is expected \
                to hold, for an archive that does not reach back to a genesis \
                or hard-fork block. Blocks at or below it are not reported as \
                missing."
             Param.(optional int)
         in
         main ~archive_uri ~min_height )))
