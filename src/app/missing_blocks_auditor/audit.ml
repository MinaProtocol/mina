(* audit.ml -- the checks of an archive database: the one implementation
   behind mina-missing-blocks-auditor and mina-missing-blocks-guardian *)

open Core_kernel
open Async

(* Why the audit could not finish: what failed, and the error text. *)
type failure = { message : string; error : string }

(* A block that the archive lacks: the parent of a block that it holds. *)
type missing_block = { parent_hash : string; parent_height : int }

type report =
  { missing_blocks : missing_block list
  ; pending_blocks_below_canonical : bool
  ; chain_length_differs : bool
  ; chain_status_invalid : bool
  }

(* The exit code of the auditor: a bit for each problem found. *)
let exit_code report =
  let bit n found = if found then 1 lsl n else 0 in
  bit 0 (not (List.is_empty report.missing_blocks))
  lor bit 1 report.pending_blocks_below_canonical
  lor bit 2 report.chain_length_differs
  lor bit 3 report.chain_status_invalid

(* Runs the checks on the database of [pool] and logs each result. A query
   that fails, or an archive with no canonical block, is an [Error]: the
   audit must not succeed on an empty canonical chain. *)
let run ~logger ~pool =
  let open Deferred.Result.Let_syntax in
  let query ~message f =
    Deferred.map
      (Mina_caqti.Pool.use f pool)
      ~f:
        (Result.map_error ~f:(fun err ->
             { message; error = Caqti_error.show err } ) )
  in
  [%log info] "Querying missing blocks" ;
  let%bind missing_blocks_raw =
    query ~message:"Error getting missing blocks" (fun db ->
        Sql.Unparented_blocks_detail.run db () )
  in
  (* filters out genesis or first fork block. This is needed as they are not considered missing and
     archive blocks can start from block with height > 1 in case of sandbox network forked from devnet/mainnet.
     Archive of such network won't include genesis block but fork block as a first block *)
  let%bind genesis_or_fork_block_height =
    query ~message:"Error getting genesis or first fork block height" (fun db ->
        Sql.GenesisOrFirstForkBlockHeight.run db () )
  in
  let unparented_blocks =
    List.filter missing_blocks_raw ~f:(fun (_, _, height, _) ->
        height <> genesis_or_fork_block_height )
  in
  let log_gap (block_id, state_hash, height, parent_hash) =
    let parent_height = height - 1 in
    let%map gap_size =
      query ~message:"Error getting missing blocks gap" (fun db ->
          Sql.Missing_blocks_gap.run db height )
    in
    [%log info] "Block has no parent in archive db"
      ~metadata:
        [ ("block_id", `Int block_id)
        ; ("state_hash", `String state_hash)
        ; ("height", `Int height)
        ; ("parent_hash", `String parent_hash)
        ; ("parent_height", `Int parent_height)
        ; ("missing_blocks_gap", `Int gap_size)
        ] ;
    { parent_hash; parent_height }
  in
  let rec log_gaps found = function
    | [] ->
        return (List.rev found)
    | block :: blocks ->
        let%bind missing_block = log_gap block in
        log_gaps (missing_block :: found) blocks
  in
  if List.is_empty unparented_blocks then
    [%log info] "There are no missing blocks in the archive db" ;
  let%bind missing_blocks = log_gaps [] unparented_blocks in
  [%log info] "Querying for gaps in chain statuses" ;
  let highest_canonical_message =
    "Error getting greatest height of canonical blocks"
  in
  let%bind highest_canonical =
    match%bind
      query ~message:highest_canonical_message (fun db ->
          Sql.Chain_status.run_highest_canonical db () )
    with
    | Some height ->
        return height
    | None ->
        Deferred.return
          (Error
             { message = highest_canonical_message
             ; error = "no canonical blocks found in archive database"
             } )
  in
  let%bind pending_below =
    query
      ~message:
        "Error getting number of pending blocks below highest canonical block"
      (fun db -> Sql.Chain_status.run_count_pending_below db highest_canonical)
  in
  let pending_blocks_below_canonical =
    not (Int64.equal pending_below Int64.zero)
  in
  if pending_blocks_below_canonical then
    [%log info]
      "There are $num_pending_blocks_below pending blocks lower than the \
       highest canonical block"
      ~metadata:
        [ ( "max_height_canonical_block"
          , `String (Int64.to_string highest_canonical) )
        ; ("num_pending_blocks_below", `String (Int64.to_string pending_below))
        ]
  else [%log info] "There are no gaps in the chain statuses" ;
  let%map canonical_chain =
    query ~message:"Error getting canonical chain" (fun db ->
        Sql.Chain_status.run_canonical_chain db highest_canonical )
  in
  let chain_len = List.length canonical_chain |> Int64.of_int in
  let chain_length_differs = not (Int64.equal chain_len highest_canonical) in
  if not chain_length_differs then
    [%log info] "Length of canonical chain is %Ld blocks" chain_len
  else if genesis_or_fork_block_height = 1 then
    [%log info] "Length of canonical chain is %Ld blocks, expected: %Ld"
      chain_len highest_canonical
  else
    [%log info]
      "Length of canonical chain is %Ld blocks, expected: %Ld. (Note: genesis \
       or first fork block has height %d)"
      chain_len highest_canonical genesis_or_fork_block_height ;
  let invalid_chain =
    List.filter canonical_chain
      ~f:(fun (_block_id, _state_hash, chain_status) ->
        not (String.equal chain_status "canonical") )
  in
  if List.is_empty invalid_chain then
    [%log info] "All blocks along the canonical chain have a valid chain status" ;
  List.iter invalid_chain ~f:(fun (block_id, state_hash, chain_status) ->
      [%log info] "Canonical block has a chain_status other than \"canonical\""
        ~metadata:
          [ ("block_id", `Int block_id)
          ; ("state_hash", `String state_hash)
          ; ("chain_status", `String chain_status)
          ] ) ;
  { missing_blocks
  ; pending_blocks_below_canonical
  ; chain_length_differs
  ; chain_status_invalid = not (List.is_empty invalid_chain)
  }
