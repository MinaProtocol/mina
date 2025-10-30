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
      Caqti_type.(string ->! int)
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
      Caqti_type.(string ->? string)
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
