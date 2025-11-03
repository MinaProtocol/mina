open Async
open Core
open Caqti_request.Infix

module type CONNECTION = Mina_caqti.CONNECTION

type genesis_block = { id : int; state_hash : string }

type block_info = { id : int; height : int64; protocol_version_id : int }

let latest_state_hash_query =
  Caqti_type.(unit ->! string)
    {sql|
          SELECT state_hash from blocks order by height desc limit 1;
        |sql}

let latest_state_hash (module Conn : CONNECTION) =
  Conn.find latest_state_hash_query ()

let genesis_block_query =
  Caqti_type.(int ->? t2 int string)
    {sql|
      SELECT id, state_hash
      FROM blocks
      WHERE protocol_version_id = ?
        AND global_slot_since_hard_fork = 0
      ORDER BY id ASC
      LIMIT 1;
    |sql}

let genesis_block (module Conn : CONNECTION) ~protocol_version =
  let open Deferred.Result.Let_syntax in
  let%map genesis = Conn.find_opt genesis_block_query protocol_version in
  Option.map genesis ~f:(fun (id, state_hash) -> { id; state_hash })

let block_info_by_state_hash_query =
  Caqti_type.(string ->? t3 int int64 int)
    {sql|
      SELECT id, height, protocol_version_id
      FROM blocks
      WHERE state_hash = ?
      LIMIT 1;
    |sql}

let block_info_by_state_hash (module Conn : CONNECTION) ~state_hash =
  let open Deferred.Result.Let_syntax in
  let%map info = Conn.find_opt block_info_by_state_hash_query state_hash in
  Option.map info ~f:(fun (id, height, protocol_version_id) ->
      { id; height; protocol_version_id } )

let canonical_chain_members_query =
  Caqti_type.(t5 int int int int int ->* t2 int int64)
    {sql|
      WITH RECURSIVE chain AS (
        SELECT id, parent_id, height
        FROM blocks
        WHERE id = ? AND protocol_version_id = ?

        UNION ALL

        SELECT b.id, b.parent_id, b.height
        FROM blocks b
        INNER JOIN chain
          ON b.id = chain.parent_id
        WHERE (chain.id <> ? OR b.id = ?)
          AND b.protocol_version_id = ?
      )
      SELECT id, height
      FROM chain
      ORDER BY height ASC;
    |sql}

let canonical_chain_ids (module Conn : CONNECTION) ~target_block_id ~genesis_id
    ~protocol_version =
  let open Deferred.Result.Let_syntax in
  let%map members =
    Conn.collect_list canonical_chain_members_query
      ( target_block_id
      , protocol_version
      , genesis_id
      , genesis_id
      , protocol_version )
  in
  List.map members ~f:fst

let orphan_blocks_query =
  Caqti_type.(t2 int (option int) ->. Caqti_type.unit)
    {sql|
      UPDATE blocks
      SET chain_status = 'orphaned'
      WHERE protocol_version_id = $1::int
        AND (global_slot_since_genesis < $2::int OR $2::int IS NULL);
    |sql}

let mark_blocks_as_orphaned (module Conn : CONNECTION) ~protocol_version
    ~stop_at_slot =
  Conn.exec orphan_blocks_query (protocol_version, stop_at_slot)

let canonical_blocks_query =
  Caqti_type.(t3 int Mina_caqti.array_int_typ (option int) ->. Caqti_type.unit)
    {sql|
      UPDATE blocks
      SET chain_status = 'canonical'
      WHERE protocol_version_id = $1::int
        AND id = ANY ($2::int[])
        AND (global_slot_since_genesis < $3::int OR $3::int IS NULL);
    |sql}

let mark_blocks_as_canonical (module Conn : CONNECTION) ~protocol_version ~ids
    ~stop_at_slot =
  let id_array = Array.of_list ids in
  Conn.exec canonical_blocks_query (protocol_version, id_array, stop_at_slot)

let chain_of_query =
  {sql|
    WITH RECURSIVE chain AS (
        SELECT
            b.id AS id,
            b.parent_id AS parent_id,
            b.state_hash AS state_hash,
            b.height AS height,
            b.global_slot_since_genesis AS global_slot_since_genesis
        FROM blocks b
        WHERE b.state_hash = ?

        UNION ALL

        SELECT
            p.id,
            p.parent_id,
            p.state_hash,
            p.height,
            p.global_slot_since_genesis
        FROM blocks p
        JOIN chain c ON p.id = c.parent_id
        WHERE p.parent_id IS NOT NULL
    )
  |sql}

let is_in_best_chain_query =
  Caqti_type.(t4 string string int int64 ->! bool)
    ( chain_of_query
    ^ {sql|
    SELECT EXISTS (
      SELECT 1 FROM chain
      WHERE state_hash = ?
        AND height = ?
        AND global_slot_since_genesis = ?
    );
    |sql}
    )

let is_in_best_chain (module Conn : CONNECTION) ~tip_hash ~check_hash
    ~check_height ~check_slot =
  Conn.find is_in_best_chain_query
    (tip_hash, check_hash, check_height, check_slot)

let num_of_confirmations_query =
  Caqti_type.(t2 string int ->! int)
    ( chain_of_query
    ^ {sql|
    SELECT count(*) FROM chain 
    WHERE global_slot_since_genesis >= ?;
    |sql}
    )

let num_of_confirmations (module Conn : CONNECTION) ~latest_state_hash
    ~fork_slot =
  Conn.find num_of_confirmations_query (latest_state_hash, fork_slot)

let number_of_commands_since_block_query block_commands_table =
  Caqti_type.(t2 string int ->! t4 string int int int)
    ( chain_of_query
    ^ Printf.sprintf
        {sql|
    SELECT 
        state_hash,
        height,
        global_slot_since_genesis,
        COUNT(bc.block_id) AS command_count
    FROM chain
    LEFT JOIN %s bc 
        ON chain.id = bc.block_id
    WHERE global_slot_since_genesis >= ?
    GROUP BY 
        state_hash,
        height,
        global_slot_since_genesis;
    |sql}
        block_commands_table )

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

let last_fork_block_query =
  Caqti_type.(unit ->! t2 string int64)
    {sql|
    SELECT state_hash, global_slot_since_genesis FROM blocks
    WHERE global_slot_since_hard_fork = 0
    ORDER BY height DESC
    LIMIT 1;
    |sql}

let last_fork_block (module Conn : CONNECTION) =
  Conn.find last_fork_block_query ()

let fetch_latest_migration_history_query =
  Caqti_type.(unit ->? t3 string string string)
    {|
      SELECT
        status, protocol_version, migration_version
      FROM migration_history
      ORDER BY commit_start_at DESC
      LIMIT 1;
    |}

let fetch_latest_migration_history (module Conn : CONNECTION) =
  Conn.find_opt fetch_latest_migration_history_query ()

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
let fetch_last_filled_block_query =
  Caqti_type.(unit ->! t3 string int64 int)
    {sql|
    SELECT b.state_hash, b.global_slot_since_genesis, b.height
    FROM blocks b
    INNER JOIN blocks_internal_commands bic ON b.id = bic.block_id
    ORDER BY b.height DESC
    LIMIT 1;
    |sql}

let fetch_last_filled_block (module Conn : CONNECTION) =
  Conn.find fetch_last_filled_block_query ()
