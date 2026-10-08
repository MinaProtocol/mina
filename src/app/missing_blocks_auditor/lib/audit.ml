(* audit.ml -- health audit of an archive database.

   The missing blocks auditor reports it; the missing blocks guardian reports
   it too, and walks [missing_parents] to backfill the gaps. *)

open Core
open Async

(** A block in the archive whose parent is not in the archive. *)
module Orphan = struct
  type t =
    { block_id : int; state_hash : string; height : int; parent_hash : string }
  [@@deriving to_yojson]

  (** Height of the parent block that has to be fetched to close this gap. *)
  let parent_height t = t.height - 1

  let to_metadata t =
    let fields = match to_yojson t with `Assoc fields -> fields | _ -> [] in
    fields @ [ ("parent_height", `Int (parent_height t)) ]
end

(** The block at the lowest height in the archive. *)
module Lowest_block = struct
  type t =
    { height : int
    ; global_slot_since_hard_fork : int64
    ; global_slot_since_genesis : int64
    }

  (** The global slot since genesis of the hard fork this block follows, or
      [None] when no hard fork lies below it. *)
  let fork_global_slot_since_genesis t =
    if Int64.equal t.global_slot_since_genesis t.global_slot_since_hard_fork
    then None
    else
      Some Int64.(t.global_slot_since_genesis - t.global_slot_since_hard_fork)
end

(** Something wrong with the archive that the audit found.  The exit code is
    0 or 1; the detail lives here and is logged, one line per problem, with
    structured metadata. *)
module Problem = struct
  type t =
    | Missing_blocks of int
    | Empty_archive
    | No_genesis_block of { lowest_height : int }
    | No_fork_block of
        { lowest_height : int; fork_global_slot_since_genesis : int64 }
    | No_canonical_blocks
    | Pending_below_canonical of { count : int64; canonical_height : int64 }
    | Canonical_chain_incomplete of { actual : int64; expected : int64 }
    | Invalid_chain_status of int
  [@@deriving equal, sexp_of]

  let message = function
    | Missing_blocks _ ->
        "Some blocks have no parent in the archive"
    | Empty_archive ->
        "The archive holds no blocks"
    | No_genesis_block _ ->
        "The archive holds no genesis block. Its lowest block comes before any \
         hard fork, so the chain starts at the genesis block at height 1. \
         Every block below the lowest stored block will be reported as \
         missing. Restore a dump that reaches back to genesis, or pass \
         --min-height with the height of the earliest block this archive is \
         expected to hold."
    | No_fork_block _ ->
        "The archive holds no first block after the hard fork that its lowest \
         block follows, so the guardian cannot tell where the post-fork chain \
         starts. Every block below the lowest stored block will be reported as \
         missing. Restore a dump that reaches back to that fork block, or pass \
         --min-height with the height of the earliest block this archive is \
         expected to hold."
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
    | Empty_archive | No_canonical_blocks ->
        []
    | No_genesis_block { lowest_height } ->
        [ ("lowest_height", `Int lowest_height) ]
    | No_fork_block { lowest_height; fork_global_slot_since_genesis } ->
        [ ("lowest_height", `Int lowest_height)
        ; ( "fork_global_slot_since_genesis"
          , `String (Int64.to_string fork_global_slot_since_genesis) )
        ]
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

(** Where the chain starts: the genesis or first post-hard-fork block, else
    the [--min-height] the operator gave, else height 1. Blocks at or below
    it are the bottom of the archive: their parents are not looked for, and
    the canonical chain is measured from it. *)
let chain_start ~genesis_or_fork_height ~min_height =
  match (genesis_or_fork_height, min_height) with
  | Some height, _ | None, Some height ->
      height
  | None, None ->
      1

module Report = struct
  type t =
    { orphans : (Orphan.t * int option) list
          (** Each orphan, paired with the size of the height gap below it.
              [None] means the archive holds no block below that orphan at
              all, so there is no gap to measure -- the orphan is the bottom
              of the archive. *)
    ; genesis_or_fork_height : int option
    ; lowest_block : Lowest_block.t option
          (** [None] when the archive holds no blocks. *)
    ; min_height : int option
          (** Height the operator declared as the start of this archive, if
              any.  A truncated or post-hard-fork archive has no genesis block
              to find, so with [--min-height] set that is not a problem. *)
    ; highest_canonical : int64 option
    ; pending_below_canonical : int64
    ; canonical_chain_length : int64
    ; invalid_chain_status : (int * string * string) list
    }

  let chain_start t =
    chain_start ~genesis_or_fork_height:t.genesis_or_fork_height
      ~min_height:t.min_height

  (* nothing says where this archive's chain starts *)
  let chain_start_unknown t =
    Option.is_none t.genesis_or_fork_height && Option.is_none t.min_height

  (* the archive holds neither the genesis block nor the first block after
     the hard fork its lowest block follows *)
  let chain_start_problem (lowest : Lowest_block.t) =
    match Lowest_block.fork_global_slot_since_genesis lowest with
    | None ->
        Problem.No_genesis_block { lowest_height = lowest.height }
    | Some fork_global_slot_since_genesis ->
        Problem.No_fork_block
          { lowest_height = lowest.height; fork_global_slot_since_genesis }

  let problems t =
    let problems = ref [] in
    let add p = problems := p :: !problems in
    if not (List.is_empty t.orphans) then
      add (Problem.Missing_blocks (List.length t.orphans)) ;
    ( match t.lowest_block with
    | None ->
        (* whatever --min-height says: a probe pointed at the wrong or an
           unloaded database must not pass *)
        add Problem.Empty_archive
    | Some lowest ->
        if chain_start_unknown t then add (chain_start_problem lowest) ) ;
    ( match t.highest_canonical with
    | None ->
        (* An empty archive is already reported as such. *)
        if Option.is_some t.lowest_block then add Problem.No_canonical_blocks
    | Some canonical_height ->
        if not (Int64.equal t.pending_below_canonical Int64.zero) then
          add
            (Problem.Pending_below_canonical
               { count = t.pending_below_canonical; canonical_height } ) ;
        let expected_chain_length =
          Int64.(canonical_height - of_int (chain_start t) + one)
        in
        if not (Int64.equal t.canonical_chain_length expected_chain_length) then
          add
            (Problem.Canonical_chain_incomplete
               { actual = t.canonical_chain_length
               ; expected = expected_chain_length
               } ) ) ;
    if not (List.is_empty t.invalid_chain_status) then
      add (Problem.Invalid_chain_status (List.length t.invalid_chain_status)) ;
    List.rev !problems

  let is_healthy t = List.is_empty (problems t)
end

(* Run one query against the pool, turning a Caqti error into an [Error.t] that
   names the query. *)
let query pool ~what f =
  match%map Mina_caqti.Pool.use f pool with
  | Ok x ->
      Ok x
  | Error err ->
      Or_error.errorf "%s failed: %s" what (Caqti_error.show err)

let genesis_or_fork_height pool =
  query pool ~what:"querying the genesis or first hard-fork block height"
    (fun db -> Sql.GenesisOrFirstForkBlockHeight.run db ())

(** Blocks whose parent is absent from the archive, above the {!chain_start}.
    The parent of the genesis block, or of the first block after a hard fork,
    is not looked for: the chain in this archive starts there. This is the
    cheap query the backfill loop repeats after every added block; it avoids
    the recursive canonical-chain query of a full {!report}. *)
let missing_parents pool ~min_height =
  let open Deferred.Or_error.Let_syntax in
  let%bind raw =
    query pool ~what:"querying blocks with no parent" (fun db ->
        Sql.Unparented_blocks_detail.run db () )
  in
  let%map genesis_height = genesis_or_fork_height pool in
  let start = chain_start ~genesis_or_fork_height:genesis_height ~min_height in
  let orphans =
    List.filter_map raw ~f:(fun (block_id, state_hash, height, parent_hash) ->
        if Int.( <= ) height start then None
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
  let%bind lowest_block =
    query pool ~what:"querying the lowest block" (fun db ->
        Sql.Lowest_block.run db () )
    >>|? Option.map
           ~f:(fun
                (height, global_slot_since_hard_fork, global_slot_since_genesis)
              ->
             { Lowest_block.height
             ; global_slot_since_hard_fork
             ; global_slot_since_genesis
             } )
  in
  let%bind highest_canonical =
    query pool ~what:"querying the greatest height of canonical blocks"
      (fun db -> Sql.Chain_status.run_highest_canonical db ())
  in
  match highest_canonical with
  | None ->
      (* No canonical block at all.  There is no chain to walk, so the
         chain-length and chain-status checks have nothing to say; the
         chain-start problem and the orphan list carry the diagnosis. *)
      return
        { Report.orphans
        ; genesis_or_fork_height
        ; lowest_block
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
      ; lowest_block
      ; min_height
      ; highest_canonical = Some highest_canonical
      ; pending_below_canonical
      ; canonical_chain_length = List.length canonical_chain |> Int64.of_int
      ; invalid_chain_status
      }

(* Log-scraping alerts match the per-block messages below; keep their wording. *)
let log_report ~logger (t : Report.t) =
  [%log info] "Querying missing blocks" ;
  ( match (t.genesis_or_fork_height, t.min_height) with
  | Some _, _ | None, None ->
      ()
  | None, Some min_height ->
      [%log info]
        "The archive holds no genesis block or first post-hard-fork block to \
         start from. --min-height says it is meant to start at $min_height, so \
         blocks below that are not reported as missing."
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
      ; lowest_block =
          Some
            { height = 1
            ; global_slot_since_hard_fork = 0L
            ; global_slot_since_genesis = 0L
            }
      ; min_height = None
      ; highest_canonical = Some 100L
      ; pending_below_canonical = 0L
      ; canonical_chain_length = 100L
      ; invalid_chain_status = []
      }

    let has_problems t expected =
      [%equal: Problem.t list] (Report.problems t) expected

    let empty_archive =
      { healthy with
        genesis_or_fork_height = None
      ; lowest_block = None
      ; highest_canonical = None
      ; canonical_chain_length = 0L
      }

    let%test "a complete archive is healthy" = Report.is_healthy healthy

    let%test "an archive with no canonical block is a problem" =
      has_problems
        { healthy with highest_canonical = None }
        [ No_canonical_blocks ]

    let%test "a hard-forked archive is not reported as too short" =
      (* 100 blocks from height 901 to 1000; measured from height 1 it would
         be 900 blocks short *)
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
      has_problems
        { healthy with canonical_chain_length = 99L }
        [ Canonical_chain_incomplete { actual = 99L; expected = 100L } ]

    let%test "a missing genesis block with no --min-height is a problem" =
      has_problems
        { healthy with
          genesis_or_fork_height = None
        ; lowest_block =
            Some
              { height = 5
              ; global_slot_since_hard_fork = 7L
              ; global_slot_since_genesis = 7L
              }
        }
        [ No_genesis_block { lowest_height = 5 } ]

    let%test "a missing fork block names the fork" =
      has_problems
        { healthy with
          genesis_or_fork_height = None
        ; lowest_block =
            Some
              { height = 905
              ; global_slot_since_hard_fork = 7L
              ; global_slot_since_genesis = 1007L
              }
        }
        [ No_fork_block
            { lowest_height = 905; fork_global_slot_since_genesis = 1000L }
        ]

    let%test "an empty archive is reported once" =
      has_problems empty_archive [ Empty_archive ]

    let%test "an empty archive is a problem even with --min-height" =
      has_problems
        { empty_archive with min_height = Some 901 }
        [ Empty_archive ]

    let%test "several problems are reported together" =
      has_problems
        { healthy with
          genesis_or_fork_height = None
        ; pending_below_canonical = 3L
        ; invalid_chain_status = [ (1, "3Nabc", "pending") ]
        }
        [ No_genesis_block { lowest_height = 1 }
        ; Pending_below_canonical { count = 3L; canonical_height = 100L }
        ; Invalid_chain_status 1
        ]
  end )
