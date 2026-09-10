(* audit.ml -- health audit of an archive database.

   This is the check that the standalone [mina-missing-blocks-auditor] used to
   perform.  It is kept as a library module here so that both the [audit]
   subcommand and the backfill loop of [single-run]/[daemon] use exactly one
   implementation and one set of SQL queries. *)

open Core
open Async

(** A block in the archive whose parent is not in the archive. *)
module Orphan = struct
  type t =
    { block_id : int; state_hash : string; height : int; parent_hash : string }

  (** Height of the parent block that has to be fetched to close this gap. *)
  let parent_height t = t.height - 1

  let to_metadata t =
    [ ("block_id", `Int t.block_id)
    ; ("state_hash", `String t.state_hash)
    ; ("height", `Int t.height)
    ; ("parent_hash", `String t.parent_hash)
    ; ("parent_height", `Int (parent_height t))
    ]
end

(** Something wrong with the archive that the audit found.  The exit code is
    simply 0 or 1 -- an operator wants "is this archive healthy" answered by
    the exit status, not decoded from a bit mask -- so the detail lives here
    and is logged, one line per problem, with structured metadata. *)
module Problem = struct
  type t =
    | Missing_blocks of int
    | No_genesis_block
    | No_canonical_blocks
    | Pending_below_canonical of { count : int64; canonical_height : int64 }
    | Canonical_chain_incomplete of { actual : int64; expected : int64 }
    | Invalid_chain_status of int

  let message = function
    | Missing_blocks _ ->
        "Some blocks have no parent in the archive"
    | No_genesis_block ->
        "The archive holds no genesis block and no first post-hard-fork block. \
         Every block below the earliest stored block will be reported as \
         missing, and the guardian cannot tell where the chain is supposed to \
         start. Restore a dump that reaches back to the start of the chain, or \
         pass --min-height with the height of the earliest block this archive \
         is expected to hold."
    | No_canonical_blocks ->
        "The archive holds no canonical block at all, so canonicalization has \
         never run on it"
    | Pending_below_canonical _ ->
        "Some blocks at or below the highest canonical block are still pending"
    | Canonical_chain_incomplete _ ->
        "The canonical chain is shorter than the range of heights it covers"
    | Invalid_chain_status _ ->
        "Some blocks along the canonical chain have another chain status"

  let metadata = function
    | Missing_blocks count ->
        [ ("blocks_without_parent", `Int count) ]
    | No_genesis_block | No_canonical_blocks ->
        []
    | Pending_below_canonical { count; canonical_height } ->
        [ ("num_pending_blocks_below", `String (Int64.to_string count))
        ; ( "max_height_canonical_block"
          , `String (Int64.to_string canonical_height) )
        ]
    | Canonical_chain_incomplete { actual; expected } ->
        [ ("canonical_chain_length", `String (Int64.to_string actual))
        ; ("expected_length", `String (Int64.to_string expected))
        ]
    | Invalid_chain_status count ->
        [ ("blocks_with_wrong_chain_status", `Int count) ]
end

module Report = struct
  type t =
    { orphans : (Orphan.t * int option) list
          (** Each orphan, paired with the size of the height gap below it.
              [None] means the archive holds no block below that orphan at
              all, so there is no gap to measure -- the orphan is the bottom
              of the archive. *)
    ; genesis_or_fork_height : int option
    ; min_height : int option
          (** Height the operator declared as the start of this archive, if
              any.  A truncated or post-hard-fork archive has no genesis block
              to find, so with [--min-height] set that is not a problem. *)
    ; highest_canonical : int64 option
    ; pending_below_canonical : int64
    ; canonical_chain_length : int64
    ; invalid_chain_status : (int * string * string) list
    }

  (** The height the canonical chain is expected to start from.  Measuring the
      chain against [highest_canonical] alone assumes it starts at height 1,
      which reports every hard-forked or truncated archive as too short. *)
  let chain_start t =
    match (t.genesis_or_fork_height, t.min_height) with
    | Some height, _ | None, Some height ->
        height
    | None, None ->
        1

  let problems t =
    let problems = ref [] in
    let add p = problems := p :: !problems in
    if not (List.is_empty t.orphans) then
      add (Problem.Missing_blocks (List.length t.orphans)) ;
    if Option.is_none t.genesis_or_fork_height && Option.is_none t.min_height
    then add Problem.No_genesis_block ;
    ( match t.highest_canonical with
    | None ->
        add Problem.No_canonical_blocks
    | Some canonical_height ->
        if not (Int64.equal t.pending_below_canonical Int64.zero) then
          add
            (Problem.Pending_below_canonical
               { count = t.pending_below_canonical; canonical_height } ) ;
        let expected =
          Int64.(canonical_height - of_int (chain_start t) + one)
        in
        if not (Int64.equal t.canonical_chain_length expected) then
          add
            (Problem.Canonical_chain_incomplete
               { actual = t.canonical_chain_length; expected } ) ) ;
    if not (List.is_empty t.invalid_chain_status) then
      add (Problem.Invalid_chain_status (List.length t.invalid_chain_status)) ;
    List.rev !problems

  let is_healthy t = List.is_empty (problems t)
end

(* Run one query against the pool, turning a Caqti error into an [Error.t] that
   names the query.  The old auditor logged [Caqti_error.show] and then called
   [exit 1] from deep inside the query helper, which made every failure look
   the same to the caller. *)
let query pool ~what f =
  match%map Mina_caqti.Pool.use f pool with
  | Ok x ->
      Ok x
  | Error err ->
      Or_error.errorf "%s failed: %s" what (Caqti_error.show err)

let genesis_or_fork_height pool =
  query pool ~what:"querying the genesis or first hard-fork block height"
    (fun db -> Sql.GenesisOrFirstForkBlockHeight.run db () )

(** Blocks whose parent is absent from the archive, excluding the genesis or
    first post-hard-fork block, which has no parent by construction.  This is
    the cheap query the backfill loop repeats after every ingested block; it
    deliberately avoids the recursive canonical-chain query of a full
    {!report}. *)
let missing_parents pool ~min_height =
  let open Deferred.Or_error.Let_syntax in
  let%bind raw =
    query pool ~what:"querying blocks with no parent" (fun db ->
        Sql.Unparented_blocks_detail.run db () )
  in
  let%map genesis_height = genesis_or_fork_height pool in
  (* A block is not missing a parent when there is no parent it could have:
     the genesis or first post-hard-fork block, a block at height 1, or -- on
     an archive the operator declared as starting higher up -- any block at or
     below [--min-height].  Those are the bottom of the archive, not a gap. *)
  let floor = Option.value min_height ~default:1 in
  let orphans =
    List.filter_map raw ~f:(fun (block_id, state_hash, height, parent_hash) ->
        if
          Option.exists genesis_height ~f:(Int.equal height)
          || Int.( <= ) height floor
        then None
        else Some { Orphan.block_id; state_hash; height; parent_hash } )
    |> List.sort ~compare:(fun a b -> Int.compare a.Orphan.height b.height)
  in
  (orphans, genesis_height)

(** Read enough of the archive to prove the connection works and the schema is
    the one we expect, before any block is downloaded. *)
let preflight pool =
  query pool ~what:"counting blocks in the archive" (fun db ->
      Sql.Block_count.run db () )

let report pool ~min_height =
  let open Deferred.Or_error.Let_syntax in
  let%bind orphans, genesis_or_fork_height = missing_parents pool ~min_height in
  let%bind orphans =
    Deferred.Or_error.List.map ~how:`Sequential orphans ~f:(fun orphan ->
        let%map gap =
          query pool ~what:"querying the size of a missing block gap" (fun db ->
              Sql.Missing_blocks_gap.run db orphan.Orphan.height )
        in
        (orphan, gap) )
  in
  let%bind highest_canonical =
    query pool ~what:"querying the greatest height of canonical blocks"
      (fun db -> Sql.Chain_status.run_highest_canonical db () )
  in
  match highest_canonical with
  | None ->
      (* No canonical block at all.  There is no chain to walk, so the
         chain-length and chain-status checks have nothing to say; the missing
         genesis bit and the orphan list carry the diagnosis. *)
      return
        { Report.orphans
        ; genesis_or_fork_height
        ; min_height
        ; highest_canonical = None
        ; pending_below_canonical = Int64.zero
        ; canonical_chain_length = Int64.zero
        ; invalid_chain_status = []
        }
  | Some highest_canonical ->
      let%bind pending_below_canonical =
        query pool
          ~what:
            "querying the number of pending blocks below the highest canonical \
             block" (fun db ->
            Sql.Chain_status.run_count_pending_below db highest_canonical )
      in
      let%map canonical_chain =
        query pool ~what:"querying the canonical chain" (fun db ->
            Sql.Chain_status.run_canonical_chain db highest_canonical )
      in
      let invalid_chain_status =
        List.filter canonical_chain ~f:(fun (_block_id, _state_hash, status) ->
            not (String.equal status "canonical") )
      in
      { Report.orphans
      ; genesis_or_fork_height
      ; min_height
      ; highest_canonical = Some highest_canonical
      ; pending_below_canonical
      ; canonical_chain_length = List.length canonical_chain |> Int64.of_int
      ; invalid_chain_status
      }

(* The per-block messages below are the ones [mina-missing-blocks-auditor]
   emitted, kept verbatim so that log-scraping alerts keep matching.  The
   summary at the end is new: it replaces the exit-code bit mask, which an
   operator had to decode by hand. *)
let log_report ~logger (t : Report.t) =
  [%log info] "Querying missing blocks" ;
  ( match (t.genesis_or_fork_height, t.min_height) with
  | Some _, _ | None, None ->
      ()
  | None, Some min_height ->
      [%log info]
        "The archive holds no genesis block and no first post-hard-fork block. \
         --min-height says it is meant to start at $min_height, so blocks \
         below that are not reported as missing."
        ~metadata:[ ("min_height", `Int min_height) ] ) ;
  if List.is_empty t.orphans then
    [%log info] "There are no missing blocks in the archive db"
  else
    List.iter t.orphans ~f:(fun (orphan, gap) ->
        let gap_metadata =
          match gap with
          | Some gap ->
              [ ("missing_blocks_gap", `Int gap) ]
          | None ->
              (* Nothing at all below this block, so the gap has no size. *)
              [ ("missing_blocks_gap", `Null)
              ; ("lowest_block_in_archive", `Bool true)
              ]
        in
        [%log info] "Block has no parent in archive db"
          ~metadata:(Orphan.to_metadata orphan @ gap_metadata) ) ;
  [%log info] "Querying for gaps in chain statuses" ;
  ( match t.highest_canonical with
  | None ->
      ()
  | Some _ ->
      if Int64.equal t.pending_below_canonical Int64.zero then
        [%log info] "There are no gaps in the chain statuses" ;
      List.iter t.invalid_chain_status
        ~f:(fun (block_id, state_hash, chain_status) ->
          [%log info]
            "Canonical block has a chain_status other than \"canonical\""
            ~metadata:
              [ ("block_id", `Int block_id)
              ; ("state_hash", `String state_hash)
              ; ("chain_status", `String chain_status)
              ] ) ) ;
  match Report.problems t with
  | [] ->
      [%log info]
        "This archive node is synced with no missing blocks back to genesis"
  | problems ->
      List.iter problems ~f:(fun problem ->
          [%log error] "%s" (Problem.message problem)
            ~metadata:(Problem.metadata problem) ) ;
      [%log error] "The archive is not healthy: $problem_count problems found"
        ~metadata:[ ("problem_count", `Int (List.length problems)) ]

let%test_module "report" =
  ( module struct
    let healthy =
      { Report.orphans = []
      ; genesis_or_fork_height = Some 1
      ; min_height = None
      ; highest_canonical = Some 100L
      ; pending_below_canonical = 0L
      ; canonical_chain_length = 100L
      ; invalid_chain_status = []
      }

    let problem_names t =
      List.map (Report.problems t) ~f:(fun p ->
          match p with
          | Problem.Missing_blocks _ ->
              "missing_blocks"
          | Problem.No_genesis_block ->
              "no_genesis_block"
          | Problem.No_canonical_blocks ->
              "no_canonical_blocks"
          | Problem.Pending_below_canonical _ ->
              "pending_below_canonical"
          | Problem.Canonical_chain_incomplete _ ->
              "canonical_chain_incomplete"
          | Problem.Invalid_chain_status _ ->
              "invalid_chain_status" )

    let%test "a complete archive is healthy" = Report.is_healthy healthy

    let%test "an archive with no canonical block is a problem" =
      (* This used to set no bit at all, so the audit could exit 0 on an
         archive where canonicalization had never run. *)
      List.equal String.equal
        (problem_names { healthy with highest_canonical = None })
        [ "no_canonical_blocks" ]

    let%test "a hard-forked archive is not reported as too short" =
      (* Chain of 100 blocks starting at height 901, tip at 1000.  Measuring
         against the tip height alone would call this 900 blocks short. *)
      Report.is_healthy
        { healthy with
          genesis_or_fork_height = Some 901
        ; highest_canonical = Some 1000L
        ; canonical_chain_length = 100L
        }

    let%test "--min-height fixes the start when there is no genesis block" =
      Report.is_healthy
        { healthy with
          genesis_or_fork_height = None
        ; min_height = Some 901
        ; highest_canonical = Some 1000L
        ; canonical_chain_length = 100L
        }

    let%test "a truly short chain is still reported" =
      List.equal String.equal
        (problem_names { healthy with canonical_chain_length = 99L })
        [ "canonical_chain_incomplete" ]

    let%test "a missing genesis block with no floor is a problem" =
      List.equal String.equal
        (problem_names { healthy with genesis_or_fork_height = None })
        [ "no_genesis_block" ]

    let%test "several problems are reported together" =
      List.equal String.equal
        (problem_names
           { healthy with
             genesis_or_fork_height = None
           ; pending_below_canonical = 3L
           ; invalid_chain_status = [ (1, "3Nabc", "pending") ]
           } )
        [ "no_genesis_block"
        ; "pending_below_canonical"
        ; "invalid_chain_status"
        ]
  end )
