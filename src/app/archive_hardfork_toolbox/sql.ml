open Caqti_request.Infix

module type CONNECTION = Mina_caqti.CONNECTION

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
   block with id $2. Used by blocks_between_both_inclusive. *)
let chain_of_query_until_inclusive =
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
        JOIN chain c ON p.id = c.parent_id AND c.id <> $2 AND c.parent_id IS NOT NULL
    )
  |sql}

let latest_state_hash (module Conn : CONNECTION) =
  let query =
    Caqti_type.(unit ->! string)
      {%string|
        SELECT state_hash from blocks order by height desc limit 1;
      |}
  in
  Conn.find query ()

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
