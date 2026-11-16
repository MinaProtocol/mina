(* convert-chain-to-canonical: settles the boundary of the newest fork genesis
   with Archive_lib.Settle_pending_blocks; --dry-run reports the same change
   and writes nothing; a boundary it cannot settle is an error. Each test case
   is a scenario (Settle_scenario), as in
   src/app/archive/tests/settle_pending_blocks, which tests the settle logic
   itself. *)

open Core
open Async
open Archive_hardfork_toolbox_lib
open Settle_scenario

(* Logic.settle_boundary, the command's core, returns [outcome]. *)
let settle_boundary ?(dry_run = false) outcome =
  Do
    ( (if dry_run then "settle_boundary, dry run" else "settle_boundary")
    , fun ctx ->
        let%map got = Logic.settle_boundary ~postgres_uri:ctx.db.uri ~dry_run in
        Or_error.bind got ~f:(check_outcome ctx outcome) )

type command_result = Succeeds | Fails_mentioning of string

(* The command, as a script runs it: it succeeds or fails. *)
let command ?(dry_run = false) expect =
  Do
    ( ( if dry_run then "convert-chain-to-canonical --dry-run"
      else "convert-chain-to-canonical" )
    , fun ctx ->
        let%map result =
          Logic.convert_chain_to_canonical ~postgres_uri:ctx.db.uri ~dry_run ()
        in
        match (expect, result) with
        | Succeeds, Ok () ->
            Ok ()
        | Succeeds, Error e ->
            Or_error.errorf "the command failed: %s" (Error.to_string_hum e)
        | Fails_mentioning expected, Ok () ->
            Or_error.errorf "expected the command to fail (%s)" expected
        | Fails_mentioning expected, Error e ->
            let msg = Error.to_string_hum e in
            if String.is_substring msg ~substring:expected then Ok ()
            else Or_error.errorf "the command failed with: %s" msg )

(* A watermark behind the fork block C: B and C are pending, D competes with
   C. *)
let dry_run_then_run =
  { name = "dry run, then run"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "B" ~parent:"A" ~height:2 Pending
      ; block "C" ~parent:"B" ~height:3 Pending
      ; block "D" ~parent:"B" ~height:3 Pending
      ; fork_genesis ~fork_block:"C" ~height:4 ()
      ]
  ; steps =
      [ settle_boundary ~dry_run:true (settled 2 1)
      ; Expect
          [ ("A", Canonical)
          ; ("B", Pending)
          ; ("C", Pending)
          ; ("D", Pending)
          ; ("genesis", Canonical)
          ]
      ; settle_boundary (settled 2 1)
      ; Expect
          [ ("A", Canonical)
          ; ("B", Canonical)
          ; ("C", Canonical)
          ; ("D", Orphaned)
          ; ("genesis", Canonical)
          ]
      ]
  }

(* An archive with no fork genesis: nothing to settle, and the command
   succeeds. *)
let nothing_to_settle =
  { name = "nothing to settle"
  ; blocks = [ block "A" ~height:1 Canonical ]
  ; steps = [ settle_boundary no_fork; command ~dry_run:true Succeeds ]
  }

(* The fork genesis is pending, which the command refuses: nothing
   changes. *)
let refuses_pending_genesis =
  { name = "refuses a pending fork genesis"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "B" ~parent:"A" ~height:2 Pending
      ; fork_genesis ~fork_block:"B" ~status:Pending ~height:3 ()
      ]
  ; steps =
      [ command (Fails_mentioning "not canonical")
      ; Expect [ ("A", Canonical); ("B", Pending); ("genesis", Pending) ]
      ]
  }

(* The fork genesis's parent, the fork block, is not in the archive. *)
let fails_without_fork_block =
  { name = "fails without the fork block"
  ; blocks =
      [ block "A" ~height:1 Canonical
      ; block "B" ~parent:"A" ~height:2 Pending
      ; fork_genesis ~height:3 ()
      ]
  ; steps =
      [ command (Fails_mentioning "fork block is not in the archive")
      ; Expect [ ("A", Canonical); ("B", Pending); ("genesis", Canonical) ]
      ]
  }

(* No canonical block above the fork block B. *)
let fails_without_canonical_ancestor =
  { name = "fails without a canonical ancestor"
  ; blocks =
      [ block "A" ~height:1 Pending
      ; block "B" ~parent:"A" ~height:2 Pending
      ; fork_genesis ~fork_block:"B" ~height:3 ()
      ]
  ; steps =
      [ command (Fails_mentioning "No canonical block below the fork block")
      ; Expect [ ("A", Pending); ("B", Pending); ("genesis", Canonical) ]
      ]
  }

let tests ~server_uri =
  let group = "convert_chain_to_canonical" in
  [ ( group
    , List.map
        ~f:(test_case ~server_uri ~group)
        [ dry_run_then_run
        ; nothing_to_settle
        ; refuses_pending_genesis
        ; fails_without_fork_block
        ; fails_without_canonical_ancestor
        ] )
  ]
