open Core
open Caqti_request.Infix

module type CONNECTION = Mina_caqti.CONNECTION

let latest_state_hash_query =
  Caqti_type.(unit ->! string)
    {sql|
          SELECT state_hash from blocks order by height desc limit 1;
        |sql}

let latest_state_hash (module Conn : CONNECTION) =
  Conn.find latest_state_hash_query ()

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

(* Fetch the most recent block that has internal commands. This block should contain last ledger state.
   Empty block or last filled block is a term used in context of stop transaction slot
   and stop network slot. Just before hard fork we want to stop including any transactions
   in the blocks. No internal, user or zkapp commands should be included in the blocks after that.
   However, blocks can still be produced with no transactions, to keep chain progressing but
   only from stop  transaction slot till stop network slot. Last filled block is the last block which
   has any transaction included in it. Therefore it is our fork candidate
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
