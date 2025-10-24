open Core
open Caqti_request.Infix

module type CONNECTION = Mina_caqti.CONNECTION

let latest_state_hash_query =
  (Caqti_type.unit ->! Caqti_type.string)
    {sql|
          SELECT state_hash from blocks order by height desc limit 1;
        |sql}

let latest_state_hash (module Conn : CONNECTION) =
  Conn.find latest_state_hash_query ()

let is_in_the_best_chain_query =
  (Caqti_type.(t4 string string int int64) ->! Caqti_type.bool)
    {sql|
    WITH RECURSIVE chain AS (
      SELECT
        b.id,
        NULLIF(b.parent_id, 0) AS parent_id,
        b.state_hash,
        b.height,
        b.global_slot_since_genesis,
        ARRAY[b.id] AS path
      FROM blocks b
      WHERE b.state_hash = ?

      UNION ALL

      SELECT
        p.id,
        NULLIF(p.parent_id, 0) AS parent_id,
        p.state_hash,
        p.height,
        p.global_slot_since_genesis,
        c.path || p.id
      FROM blocks p
      JOIN chain c ON p.id = c.parent_id
      WHERE NOT p.id = ANY (c.path)
    )
    SELECT EXISTS (
      SELECT 1 FROM chain
      WHERE state_hash = ?
        AND height = ?
        AND global_slot_since_genesis = ?
    ) AS is_in_chain;
    |sql}

let is_in_the_best_chain (module Conn : CONNECTION) ~tip_hash ~check_hash
    ~check_height ~check_slot () =
  Conn.find is_in_the_best_chain_query
    (tip_hash, check_hash, check_height, check_slot)

let no_of_confirmations_query =
  (Caqti_type.(t2 string int) ->! Caqti_type.int)
    {sql|
    WITH RECURSIVE chain AS
(
    SELECT id, parent_id, chain_status, state_hash, height, global_slot_since_genesis FROM blocks
    WHERE state_hash = ?

    UNION ALL
    SELECT b.id, b.parent_id, b.chain_status, b.state_hash, b.height, b.global_slot_since_genesis FROM blocks b
    INNER JOIN chain ON b.id = chain.parent_id AND (chain.id <> 0 OR b.id = 0)
 ) SELECT count(*) FROM chain where global_slot_since_genesis >= ?;
    |sql}

let no_of_confirmations (module Conn : CONNECTION) ~latest_state_hash ~fork_slot
    =
  Conn.find no_of_confirmations_query (latest_state_hash, fork_slot)

let number_of_user_commands_since_block_query =
  (Caqti_type.(t2 string int) ->! Caqti_type.(t4 string int int int))
    {sql|
    WITH RECURSIVE chain AS
(
    SELECT id, parent_id, chain_status, state_hash, height, global_slot_since_genesis FROM blocks
    WHERE state_hash = ?
    UNION ALL
    SELECT b.id, b.parent_id, b.chain_status, b.state_hash, b.height, b.global_slot_since_genesis FROM blocks b
    INNER JOIN chain ON b.id = chain.parent_id AND (chain.id <> 0 OR b.id = 0)
 ) SELECT state_hash,  height, global_slot_since_genesis, count(bc.block_id) as user_command_count  FROM chain left join blocks_user_commands bc on bc.block_id = id where global_slot_since_genesis >= ? group by state_hash, height, global_slot_since_genesis;
    |sql}

let number_of_user_commands_since_block (module Conn : CONNECTION)
    ~fork_state_hash ~fork_slot =
  Conn.find number_of_user_commands_since_block_query
    (fork_state_hash, fork_slot)

let number_of_internal_commands_since_block_query =
  (Caqti_type.(t2 string int) ->! Caqti_type.(t4 string int int int))
    {sql|
    WITH RECURSIVE chain AS
    (
        SELECT id, parent_id, chain_status, state_hash, height, global_slot_since_genesis FROM blocks
        WHERE state_hash = ?
        UNION ALL
        SELECT b.id, b.parent_id, b.chain_status, b.state_hash, b.height, b.global_slot_since_genesis FROM blocks b
        INNER JOIN chain ON b.id = chain.parent_id AND (chain.id <> 0 OR b.id = 0)
     ) SELECT state_hash,  height, global_slot_since_genesis, count(bc.block_id) as internal_command_count  FROM chain left join blocks_internal_commands bc on bc.block_id = id where global_slot_since_genesis >= ? group by state_hash, height, global_slot_since_genesis
;
    |sql}

let number_of_internal_commands_since_block (module Conn : CONNECTION)
    ~fork_state_hash ~fork_slot =
  Conn.find number_of_internal_commands_since_block_query
    (fork_state_hash, fork_slot)

let number_of_zkapps_commands_since_block_query =
  (Caqti_type.(t2 string int) ->! Caqti_type.(t4 string int int int))
    {sql|
    WITH RECURSIVE chain AS
    (
        SELECT id, parent_id, chain_status, state_hash, height, global_slot_since_genesis FROM blocks
        WHERE state_hash = ?
        UNION ALL
        SELECT b.id, b.parent_id, b.chain_status, b.state_hash, b.height, b.global_slot_since_genesis FROM blocks b
        INNER JOIN chain ON b.id = chain.parent_id AND (chain.id <> 0 OR b.id = 0)
     ) SELECT state_hash,  height, global_slot_since_genesis, count(bc.block_id) as zkapp_command_count  FROM chain left join blocks_zkapp_commands bc on bc.block_id = id where global_slot_since_genesis >= ? group by state_hash, height, global_slot_since_genesis
;
    |sql}

let number_of_zkapps_commands_since_block (module Conn : CONNECTION)
    ~fork_state_hash ~fork_slot =
  Conn.find number_of_zkapps_commands_since_block_query
    (fork_state_hash, fork_slot)

let last_fork_block_query =
  (Caqti_type.unit ->! Caqti_type.(t2 string int64))
    {sql|
    SELECT state_hash, global_slot_since_genesis FROM blocks
    WHERE global_slot_since_hard_fork = 0
    ORDER BY height DESC
    LIMIT 1;
    |sql}

let last_fork_block (module Conn : CONNECTION) =
  Conn.find last_fork_block_query ()

module SchemaVerification = struct
  module Types = struct
    type schema_row =
      { status : string option
      ; description : string option
      ; applied_at : string
      ; validated_at : string option
      }

    type result =
      { missing_cols : int
      ; total_fks : int
      ; valid_fks : int
      ; expected_cols_min : int
      ; expected_cols_max : int
      ; expected_fk_count : int
      ; schema : schema_row option
      ; ok_cols : bool
      ; ok_fk_present : bool
      ; ok_fk_validated : bool
      ; ok_schema_status : bool
      ; ok : bool
      }
  end

  module Queries = struct
    (* 1) How many of element8..element31 are missing in table ? *)
    let missing_cols_req =
      (Caqti_type.string ->! Caqti_type.int)
      @@ {|
      SELECT count(*) FROM generate_series(8,31) g(n)
      LEFT JOIN information_schema.columns c
        ON c.table_schema='public'
       AND c.table_name=?
       AND c.column_name='element'||g.n
      WHERE c.column_name IS NULL
    |}

    (* 2) Row from public.schema_version for a given version.
          We stringify timestamps for driver simplicity. *)
    let schema_row_req =
      (Caqti_type.string ->? Caqti_type.string)
      @@ {|
      SELECT
        status
      FROM migration_history
      WHERE protocol_version = ?
    |}
  end

  let fetch_missing_cols (module Conn : CONNECTION) ~table =
    Conn.find Queries.missing_cols_req table

  let fetch_schema_row (module Conn : CONNECTION) ~version =
    Conn.find_opt Queries.schema_row_req version
end
