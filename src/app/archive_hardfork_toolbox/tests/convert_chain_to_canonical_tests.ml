(* convert-chain-to-canonical: settles the boundary of the newest fork genesis
   with Archive_lib.Settle_pending_blocks; --dry-run reports the same change
   and writes nothing; a boundary it cannot settle is an error. A test case is
   its input blocks and the chain statuses they end with (Settle_scenario), as
   in src/app/archive/tests/settle_pending_blocks, which tests the settle
   logic itself.

   Each case runs Logic.settle_boundary as a dry run, which reports the
   outcome and changes nothing, then the command, which succeeds and changes
   the outcome's blocks, or fails when the outcome is a refusal. *)

open Core
open Async
open Archive_hardfork_toolbox_lib
open Settle_scenario

(* What the command's error says for each refusal. *)
let refusal_message : Settle.boundary -> string = function
  | Fork_genesis_not_canonical ->
      "not canonical"
  | No_fork_block ->
      "fork block is not in the archive"
  | No_canonical_ancestor ->
      "No canonical block below the fork block"
  | Settled _ ->
      failwith "a settled boundary is not a refusal"

let convert_test ~server_uri (c : case) =
  test ~server_uri ~group:"convert_chain_to_canonical" ~name:c.name c.blocks
    (fun ctx ->
      let open Deferred.Or_error.Let_syntax in
      let%bind () =
        step "settle_boundary, dry run"
          (let%bind got =
             Logic.settle_boundary ~postgres_uri:ctx.db.uri ~dry_run:true
           in
           let%bind () = Deferred.return (check_result ctx c.outcome got) in
           check_statuses ctx [] )
      in
      step "convert-chain-to-canonical"
        (let%bind.Deferred result =
           Logic.convert_chain_to_canonical ~postgres_uri:ctx.db.uri
             ~dry_run:false ()
         in
         match (c.outcome, result) with
         | (Settled _ | Nothing_to_settle), Ok () ->
             check_statuses ctx (changes c.outcome)
         | (Settled _ | Nothing_to_settle), Error e ->
             Deferred.Or_error.errorf "the command failed: %s"
               (Error.to_string_hum e)
         | Refused reason, Ok () ->
             Deferred.Or_error.errorf "expected the command to fail (%s)"
               (refusal_message reason)
         | Refused reason, Error e ->
             let msg = Error.to_string_hum e in
             if String.is_substring msg ~substring:(refusal_message reason) then
               check_statuses ctx []
             else Deferred.Or_error.errorf "the command failed with: %s" msg ) )

let cases =
  [ (* A watermark behind the fork block C: B and C are pending, D competes
       with C. *)
    { name = "settles a pending fork block"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Pending
        ; block "C" ~parent:"B" ~height:3 Pending
        ; block "D" ~parent:"B" ~height:3 Pending
        ; fork_genesis ~fork_block:"C" ~height:4 ()
        ]
    ; outcome = Settled [ ("B", Canonical); ("C", Canonical); ("D", Orphaned) ]
    }
  ; (* An archive with no fork genesis: the command succeeds. *)
    { name = "nothing to settle"
    ; blocks = [ block "A" ~height:1 Canonical ]
    ; outcome = Nothing_to_settle
    }
  ; { name = "refuses a pending fork genesis"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Pending
        ; fork_genesis ~fork_block:"B" ~status:Pending ~height:3 ()
        ]
    ; outcome = Refused Fork_genesis_not_canonical
    }
  ; (* The fork genesis's parent, the fork block, is not in the archive. *)
    { name = "fails without the fork block"
    ; blocks =
        [ block "A" ~height:1 Canonical
        ; block "B" ~parent:"A" ~height:2 Pending
        ; fork_genesis ~height:3 ()
        ]
    ; outcome = Refused No_fork_block
    }
  ; (* No canonical block above the fork block B. *)
    { name = "fails without a canonical ancestor"
    ; blocks =
        [ block "A" ~height:1 Pending
        ; block "B" ~parent:"A" ~height:2 Pending
        ; fork_genesis ~fork_block:"B" ~height:3 ()
        ]
    ; outcome = Refused No_canonical_ancestor
    }
  ]

let tests ~server_uri =
  [ ("convert_chain_to_canonical", List.map cases ~f:(convert_test ~server_uri))
  ]
