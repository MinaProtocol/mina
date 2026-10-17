open Core
open Caqti_request.Infix

module type CONNECTION = Mina_caqti.CONNECTION

module Protocol_version = struct
  type t = { transaction : int; network : int; patch : int } [@@deriving equal]

  let of_string : string -> t = function
    | version_str -> (
        try
          Scanf.sscanf version_str "%d.%d.%d" (fun transaction network patch ->
              { transaction; network; patch } )
        with _ ->
          failwithf
            "Invalid protocol version string: %s. Expected format \
             <network>.<transaction>.<patch>"
            version_str () )

  let to_string { transaction; network; patch } =
    sprintf "%d.%d.%d" transaction network patch

  let typ =
    let encode { transaction; network; patch } =
      Ok (transaction, network, patch)
    in
    let decode (transaction, network, patch) =
      Ok { transaction; network; patch }
    in
    Caqti_type.(custom ~encode ~decode (t3 int int int))
end

module Block_info = struct
  type t =
    { id : int
    ; height : int64
    ; state_hash : string
    ; protocol_version : Protocol_version.t
    }

  let typ =
    let encode { id; height; state_hash; protocol_version } =
      Ok (id, height, state_hash, protocol_version)
    in
    let decode (id, height, state_hash, protocol_version) =
      Ok { id; height; state_hash; protocol_version }
    in
    Caqti_type.(
      custom ~encode ~decode (t4 int int64 string Protocol_version.typ))
end

(* Walks the parent chain from the block whose state hash is $1 back to genesis.
   Used by the callers that start from a state hash (is-in-best-chain,
   confirmations, no-commands-after). *)
let chain_of_query =
  {sql|
    WITH RECURSIVE chain AS (
        SELECT
            b.id AS id,
            b.parent_id AS parent_id,
            b.state_hash AS state_hash,
            b.height AS height,
            b.global_slot_since_genesis AS global_slot_since_genesis,
            b.protocol_version_id AS protocol_version_id
        FROM blocks b
        WHERE b.state_hash = $1

        UNION ALL

        SELECT
            p.id,
            p.parent_id,
            p.state_hash,
            p.height,
            p.global_slot_since_genesis,
            p.protocol_version_id
        FROM blocks p
        JOIN chain c ON p.id = c.parent_id AND c.parent_id IS NOT NULL
    )
  |sql}

(* Walks the parent chain from the block with id $1 down to (and including) the
   block with id $2. *)
let latest_state_hash (module Conn : CONNECTION) =
  let query =
    Caqti_type.(unit ->! string)
      {%string|
        SELECT state_hash from blocks order by height desc limit 1;
      |}
  in
  Conn.find query ()

(* Returns the first block of a specific protocol version.
   NOTE: There exists some emergency HF that doesn't bump up protocol version. *)
(* Auto-detect the latest hard-fork boundary: the parent of the highest hard-fork
   block (global_slot_since_hard_fork = 0). The genesis block also has
   global_slot_since_hard_fork = 0 but has no parent, so it is excluded. The
   returned block is the last pre-fork block that should remain canonical, and its
   protocol version is the pre-fork one whose chain we want to finalize. *)
(* Context about the hard fork just above the target: the post-fork genesis block
   (global_slot_since_hard_fork = 0) and its parent (the last pre-fork block). *)
module Fork_context = struct
  type t =
    { fork_state_hash : string
    ; fork_height : int64
    ; fork_slot : int64
    ; fork_chain_status : string
    ; parent_state_hash : string option
    ; parent_height : int64 option
    }

  let typ =
    let encode
        { fork_state_hash
        ; fork_height
        ; fork_slot
        ; fork_chain_status
        ; parent_state_hash
        ; parent_height
        } =
      Ok
        ( (fork_state_hash, fork_height, fork_slot)
        , (fork_chain_status, parent_state_hash, parent_height) )
    in
    let decode
        ( (fork_state_hash, fork_height, fork_slot)
        , (fork_chain_status, parent_state_hash, parent_height) ) =
      Ok
        { fork_state_hash
        ; fork_height
        ; fork_slot
        ; fork_chain_status
        ; parent_state_hash
        ; parent_height
        }
    in
    Caqti_type.(
      custom ~encode ~decode
        (t2 (t3 string int64 int64) (t3 string (option string) (option int64))))
end

(* The first hard-fork block (global_slot_since_hard_fork = 0) strictly above the
   target height, i.e. the post-fork genesis, together with its parent. Its slot
   is used as an upper bound for orphaning so that, when the fork does NOT bump the
   protocol version (some emergency hard forks), the post-fork chain — which shares
   the protocol version with the pre-fork chain — is not orphaned. Returns None
   when there is no hard fork above the target (e.g. the tip is pre-fork). *)
(* The blocks that will be orphaned: same protocol version, below the fork
   boundary and within the slot filter, not on the canonical chain to the target,
   and not already orphaned. These are the competing / leftover blocks. *)
(* Counts, over the blocks the conversion would touch (subject to the same slot
   and fork-boundary filters as the mutation), how many become canonical and how
   many become orphaned, plus how many currently-pending blocks change status in
   each direction. Returned as (to_canonical, pending_to_canonical, to_orphaned,
   pending_to_orphaned). The orphaned count excludes rows already orphaned so it
   matches the printed change plan and a re-run reports 0 rather than recounting
   settled blocks. *)
let is_in_best_chain (module Conn : CONNECTION) ~tip_hash ~check_hash
    ~check_height ~check_slot =
  let query =
    Caqti_type.(t4 string string int int64 ->! bool)
      {%string|
        %{chain_of_query}
        SELECT EXISTS (
          SELECT 1 FROM chain
          WHERE state_hash = $2
            AND height = $3
            AND global_slot_since_genesis = $4
        );
      |}
  in
  Conn.find query (tip_hash, check_hash, check_height, check_slot)

let num_of_confirmations (module Conn : CONNECTION) ~latest_state_hash
    ~fork_slot =
  let query =
    Caqti_type.(t2 string int ->! int)
      {%string|
        %{chain_of_query}
        SELECT COUNT(*) FROM chain 
        WHERE global_slot_since_genesis >= $2;
      |}
  in
  Conn.find query (latest_state_hash, fork_slot)

let number_of_commands_since_block_query block_commands_table =
  Caqti_type.(t2 string int ->! t4 string int int int)
    {%string|
      %{chain_of_query}
      SELECT 
          state_hash,
          height,
          global_slot_since_genesis,
          COUNT(bc.block_id) AS command_count
      FROM chain
      LEFT JOIN %{block_commands_table} bc 
          ON chain.id = bc.block_id
      WHERE global_slot_since_genesis >= $2
      GROUP BY 
          state_hash,
          height,
          global_slot_since_genesis;
    |}

let number_of_user_commands_since_block (module Conn : CONNECTION)
    ~fork_state_hash ~fork_slot =
  Conn.find
    (number_of_commands_since_block_query "blocks_user_commands")
    (fork_state_hash, fork_slot)

let number_of_internal_commands_since_block (module Conn : CONNECTION)
    ~fork_state_hash ~fork_slot =
  Conn.find
    (number_of_commands_since_block_query "blocks_internal_commands")
    (fork_state_hash, fork_slot)

let number_of_zkapps_commands_since_block (module Conn : CONNECTION)
    ~fork_state_hash ~fork_slot =
  Conn.find
    (number_of_commands_since_block_query "blocks_zkapp_commands")
    (fork_state_hash, fork_slot)

let last_fork_block (module Conn : CONNECTION) =
  let query =
    Caqti_type.(unit ->! t2 string int64)
      {%string|
        SELECT state_hash, global_slot_since_genesis FROM blocks
        WHERE global_slot_since_hard_fork = 0
        ORDER BY height DESC
        LIMIT 1;
      |}
  in
  Conn.find query ()

let fetch_latest_migration_history (module Conn : CONNECTION) =
  let query =
    Caqti_type.(unit ->? t3 string string string)
      {%string|
        SELECT
          status, protocol_version, migration_version
        FROM migration_history
        ORDER BY commit_start_at DESC
        LIMIT 1;
      |}
  in
  Conn.find_opt query ()

(* Fetches last filled block before stop transaction slot.

   Every block in mina should have internal commands since system transactions (like coinbase, fee transfer etc)
   are implemented as internal commands. It CAN have zero user commands and zero zkapp commands,
   but it should have internal commands.

   However, in context of hard fork, we want to stop including any transactions
   in the blocks after specified slot (called stop transaction slot). No internal, user or zkapp commands should be included in the blocks after that slot.
   Blocks can still be produced with no transactions, to keep chain progressing and give us confirmations but
   only from stop transaction slot till stop network slot, where we completely stop the chain.
   Knowing above we can detect last filled block by only looking at internal transactions occurrence.
   Therefore our fork candidate is the block with highest height that has internal transaction included in it.
*)

let fetch_last_filled_block (module Conn : CONNECTION) =
  let query =
    Caqti_type.(unit ->! t3 string int64 int)
      {%string|
        SELECT b.state_hash, b.global_slot_since_genesis, b.height
        FROM blocks b
        INNER JOIN blocks_internal_commands bic ON b.id = bic.block_id
        ORDER BY b.height DESC
        LIMIT 1;
      |}
  in
  Conn.find query ()
