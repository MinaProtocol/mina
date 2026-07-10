open Async
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

let chain_of_query_templated ~join_condition =
  {%string|
    WITH RECURSIVE chain AS (
        SELECT
            b.id AS id,
            b.parent_id AS parent_id,
            b.state_hash AS state_hash,
            b.height AS height,
            b.global_slot_since_genesis AS global_slot_since_genesis,
            b.protocol_version_id AS protocol_version_id
        FROM blocks b
        WHERE b.id = $1

        UNION ALL

        SELECT
            p.id,
            p.parent_id,
            p.state_hash,
            p.height,
            p.global_slot_since_genesis,
            p.protocol_version_id
        FROM blocks p
        JOIN chain c ON p.id = c.parent_id AND %{join_condition} AND c.parent_id IS NOT NULL
    )
  |}

let chain_of_query = chain_of_query_templated ~join_condition:"TRUE"

let chain_of_query_until_inclusive =
  chain_of_query_templated ~join_condition:"c.id <> $2"

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
let first_block_of_protocol_version (module Conn : CONNECTION)
    ~(v : Protocol_version.t) =
  let query =
    (Protocol_version.typ ->? Block_info.typ)
      {%string|
        SELECT blocks.id, height, state_hash, protocol_versions.transaction, protocol_versions.network, protocol_versions.patch
        FROM blocks INNER JOIN protocol_versions
          ON blocks.protocol_version_id = protocol_versions.id
        WHERE protocol_versions.transaction = $1::int
          AND protocol_versions.network = $2::int
          AND protocol_versions.patch = $3::int
          AND global_slot_since_hard_fork = 0
        ORDER BY id ASC
        LIMIT 1;
      |}
  in
  Conn.find_opt query v

let block_info_by_state_hash (module Conn : CONNECTION) ~state_hash =
  let query =
    Caqti_type.(string ->? Block_info.typ)
      {%string|
        SELECT blocks.id, height, state_hash, protocol_versions.transaction, protocol_versions.network, protocol_versions.patch
        FROM blocks INNER JOIN protocol_versions
          ON blocks.protocol_version_id = protocol_versions.id
        WHERE state_hash = ?
        LIMIT 1;
      |}
  in
  Conn.find_opt query state_hash

let blocks_info_by_height (module Conn : CONNECTION) ~height =
  let query =
    Caqti_type.(int64 ->* Block_info.typ)
      {%string|
        SELECT blocks.id, height, state_hash, protocol_versions.transaction, protocol_versions.network, protocol_versions.patch
        FROM blocks INNER JOIN protocol_versions
          ON blocks.protocol_version_id = protocol_versions.id
        WHERE height = ?;
      |}
  in
  Conn.collect_list query height

(* Auto-detect the latest hard-fork boundary: the parent of the highest hard-fork
   block (global_slot_since_hard_fork = 0). The genesis block also has
   global_slot_since_hard_fork = 0 but has no parent, so it is excluded. The
   returned block is the last pre-fork block that should remain canonical, and its
   protocol version is the pre-fork one whose chain we want to finalize. *)
let parent_of_latest_fork_block (module Conn : CONNECTION) =
  let query =
    Caqti_type.(unit ->? Block_info.typ)
      {%string|
        SELECT parent.id, parent.height, parent.state_hash, pv.transaction, pv.network, pv.patch
        FROM blocks fork
        INNER JOIN blocks parent ON parent.id = fork.parent_id
        INNER JOIN protocol_versions pv ON parent.protocol_version_id = pv.id
        WHERE fork.global_slot_since_hard_fork = 0
          AND fork.parent_id IS NOT NULL
        ORDER BY fork.height DESC
        LIMIT 1;
      |}
  in
  Conn.find_opt query ()

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
let fork_block_above_height (module Conn : CONNECTION) ~height =
  let query =
    Caqti_type.(int64 ->? Fork_context.typ)
      {%string|
        SELECT fork.state_hash, fork.height, fork.global_slot_since_genesis,
               fork.chain_status::text, parent.state_hash, parent.height
        FROM blocks fork
        LEFT JOIN blocks parent ON parent.id = fork.parent_id
        WHERE fork.global_slot_since_hard_fork = 0
          AND fork.height > ?
        ORDER BY fork.global_slot_since_genesis ASC
        LIMIT 1;
      |}
  in
  Conn.find_opt query height

(* The blocks that will be orphaned: same protocol version, below the fork
   boundary and within the slot filter, not on the canonical chain to the target,
   and not already orphaned. These are the competing / leftover blocks. *)
let blocks_to_orphan (module Conn : CONNECTION) ~canonical_block_ids
    ~stop_at_slot ~fork_boundary_slot ~protocol_version =
  let query =
    Caqti_type.(
      t4 (option int) Mina_caqti.array_int_typ Protocol_version.typ
        (option int64)
      ->* t3 int64 string string)
      {%string|
        SELECT height, state_hash, chain_status::text
        FROM blocks
        WHERE ($1 IS NULL OR $1::int <= global_slot_since_genesis)
          AND ($6 IS NULL OR global_slot_since_genesis < $6::bigint)
          AND NOT (id = ANY($2::int[]))
          AND chain_status <> 'orphaned'::chain_status_type
          AND protocol_version_id = (
            SELECT id FROM protocol_versions
            WHERE transaction = $3::int
              AND network = $4::int
              AND patch = $5::int
            LIMIT 1
          )
        ORDER BY height ASC;
      |}
  in
  Conn.collect_list query
    ( stop_at_slot
    , Array.of_list canonical_block_ids
    , protocol_version
    , fork_boundary_slot )

(* Counts, over the blocks the conversion would touch (subject to the same slot
   and fork-boundary filters as the mutation), how many would become orphaned and
   how many currently-pending blocks change status in each direction. *)
let conversion_summary_counts (module Conn : CONNECTION) ~canonical_block_ids
    ~stop_at_slot ~fork_boundary_slot ~protocol_version =
  let query =
    Caqti_type.(
      t4 (option int) Mina_caqti.array_int_typ Protocol_version.typ
        (option int64)
      ->! t3 int int int)
      {%string|
        SELECT
          COUNT(*) FILTER (WHERE NOT (id = ANY($2::int[])))::int,
          COUNT(*) FILTER (WHERE chain_status = 'pending'::chain_status_type
                             AND id = ANY($2::int[]))::int,
          COUNT(*) FILTER (WHERE chain_status = 'pending'::chain_status_type
                             AND NOT (id = ANY($2::int[])))::int
        FROM blocks
        WHERE ($1 IS NULL OR $1::int <= global_slot_since_genesis)
          AND ($6 IS NULL OR global_slot_since_genesis < $6::bigint)
          AND protocol_version_id = (
            SELECT id FROM protocol_versions
            WHERE transaction = $3::int
              AND network = $4::int
              AND patch = $5::int
            LIMIT 1
          );
      |}
  in
  Conn.find query
    ( stop_at_slot
    , Array.of_list canonical_block_ids
    , protocol_version
    , fork_boundary_slot )

(* The blocks in the canonical set that are NOT already canonical, i.e. the ones
   actually being healed. Used to print a concise, meaningful list instead of the
   whole ancestry (most of which is already canonical). *)
let noncanonical_blocks_in_set (module Conn : CONNECTION) ~canonical_block_ids =
  let query =
    Caqti_type.(Mina_caqti.array_int_typ ->* t3 int64 string string)
      {%string|
        SELECT height, state_hash, chain_status::text
        FROM blocks
        WHERE id = ANY(?::int[])
          AND chain_status <> 'canonical'::chain_status_type
        ORDER BY height ASC;
      |}
  in
  Conn.collect_list query (Array.of_list canonical_block_ids)

let mark_pending_blocks_as_canonical_or_orphaned (module Conn : CONNECTION)
    ~canonical_block_ids ~stop_at_slot ~fork_boundary_slot ~protocol_version =
  let mutation =
    Caqti_type.(
      t4 (option int) Mina_caqti.array_int_typ Protocol_version.typ
        (option int64)
      ->. Caqti_type.unit)
      {%string|
        UPDATE blocks
        SET chain_status = CASE
            WHEN id = ANY($2::int[]) THEN 'canonical'::chain_status_type
            ELSE 'orphaned'::chain_status_type
        END
        WHERE ($1 IS NULL OR $1::int <= global_slot_since_genesis)
          -- Never touch blocks at or beyond the fork boundary: when the fork does
          -- not bump the protocol version, those are the post-fork chain and must
          -- stay canonical. Canonical-set members are always pre-fork, so the
          -- extra clause keeps them included.
          AND (id = ANY($2::int[])
               OR $6 IS NULL
               OR global_slot_since_genesis < $6::bigint)
          AND protocol_version_id = (
            SELECT id FROM protocol_versions
            WHERE transaction = $3::int
              AND network = $4::int
              AND patch = $5::int
            LIMIT 1
          );
      |}
  in
  Conn.exec mutation
    ( stop_at_slot
    , Array.of_list canonical_block_ids
    , protocol_version
    , fork_boundary_slot )

let blocks_between_both_inclusive (module Conn : CONNECTION) ~latest_block_id
    ~oldest_block_id : (Block_info.t list, Caqti_error.t) Deferred.Result.t =
  let query =
    Caqti_type.(t2 int int ->* Block_info.typ)
      {%string|
        %{chain_of_query_until_inclusive}
        SELECT chain.id, height, state_hash, protocol_versions.transaction, protocol_versions.network, protocol_versions.patch
        FROM chain INNER JOIN protocol_versions
          ON chain.protocol_version_id = protocol_versions.id
        ORDER BY height ASC
      |}
  in
  Conn.collect_list query (latest_block_id, oldest_block_id)

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
