open Caqti_async

let dump_sql_to_csv output_file ~sql =
  Printf.sprintf "COPY ( %s ) TO '%s' DELIMITER ',' CSV HEADER " sql output_file

module Mainnet = struct
  let dump_state_and_ledger_hashes_to_csv_query ~output_file =
    (* Workaround for replacing output file as caqti has an issue with using ? in place of FILE argument*)
    dump_sql_to_csv output_file
      ~sql:
        "  SELECT state_hash, ledger_hash FROM blocks\n\
        \            WHERE chain_status = 'canonical'\n\
        \          "
    |> Caqti_request.exec Caqti_type.unit

  let dump_block_hashes_till_height_query ~output_file ~height =
    dump_sql_to_csv output_file
      ~sql:
        (Printf.sprintf
           "\n\
           \      SELECT state_hash, ledger_hash FROM blocks\n\
           \            WHERE chain_status = 'canonical'\n\
           \            AND height <= %d ORDER BY height\n\
           \      " height )
    |> Caqti_request.exec Caqti_type.unit

  let dump_block_hashes_till_height (module Conn : CONNECTION) output_file
      height =
    Conn.exec (dump_block_hashes_till_height_query ~output_file ~height) ()

  let dump_block_hashes_query ~output_file =
    dump_sql_to_csv output_file
      ~sql:
        "\n\
        \      SELECT state_hash, ledger_hash FROM blocks\n\
        \            WHERE chain_status = 'canonical'\n\
        \            ORDER BY height\n\
        \      "
    |> Caqti_request.exec Caqti_type.unit

  let dump_block_hashes (module Conn : CONNECTION) output_file =
    Conn.exec (dump_block_hashes_query ~output_file) ()

  let dump_user_commands_till_height_query ~output_file ~height =
    dump_sql_to_csv output_file
      ~sql:
        (Printf.sprintf
           "WITH user_command_ids AS\n\
           \      ( SELECT height, sequence_no, user_command_id FROM \
            blocks_user_commands\n\
           \        INNER JOIN blocks ON blocks.id = block_id\n\
           \        WHERE chain_status = 'canonical'\n\
           \        AND height <= %d\n\
           \      )\n\
           \      SELECT receiver_keys.value, fee_payer_keys.value, nonce, \
            amount, fee, valid_until, memo, hash FROM user_commands\n\
           \      INNER JOIN user_command_ids ON user_command_id = id\n\
           \      INNER JOIN public_keys AS receiver_keys  ON receiver_id  = \
            receiver_keys.id\n\
           \      INNER JOIN public_keys AS fee_payer_keys ON fee_payer_id = \
            fee_payer_keys.id ORDER BY height, sequence_no\n\
           \      " height )
    |> Caqti_request.exec Caqti_type.unit

  let dump_user_commands_till_height (module Conn : CONNECTION) output_file
      height =
    Conn.exec (dump_user_commands_till_height_query ~output_file ~height) ()

  let dump_internal_commands_till_height_query ~output_file ~height =
    dump_sql_to_csv output_file
      ~sql:
        (Printf.sprintf
           "WITH internal_command_ids AS \n\
           \        ( SELECT internal_command_id, height, sequence_no, \
            secondary_sequence_no FROM blocks_internal_commands \n\
           \          INNER JOIN blocks ON blocks.id = block_id \n\
           \          WHERE chain_status = 'canonical'\n\
           \          AND height <= %d\n\
           \        ) \n\
           \        SELECT receiver_keys.value, fee, sequence_no, \
            secondary_sequence_no, hash FROM internal_commands \n\
           \        INNER JOIN internal_command_ids ON internal_command_id = id\n\
           \        INNER JOIN public_keys AS receiver_keys  ON receiver_id  = \
            receiver_keys.id\n\
           \        ORDER BY height, sequence_no, secondary_sequence_no, type \n\
           \   \n\
           \          " height )
    |> Caqti_request.exec Caqti_type.unit

  let dump_internal_commands_till_height (module Conn : CONNECTION) output_file
      height =
    Conn.exec (dump_internal_commands_till_height_query ~output_file ~height) ()

  let dump_user_commands_query ~output_file =
    dump_sql_to_csv output_file
      ~sql:
        "WITH user_command_ids AS\n\
        \      ( SELECT height, sequence_no, user_command_id FROM \
         blocks_user_commands\n\
        \        INNER JOIN blocks ON blocks.id = block_id\n\
        \        WHERE chain_status = 'canonical'\n\
        \      )\n\
        \      SELECT receiver_keys.value, fee_payer_keys.value, nonce, \
         amount, fee, valid_until, memo, hash FROM user_commands\n\
        \      INNER JOIN user_command_ids ON user_command_id = id\n\
        \      INNER JOIN public_keys AS receiver_keys  ON receiver_id  = \
         receiver_keys.id\n\
        \      INNER JOIN public_keys AS fee_payer_keys ON fee_payer_id = \
         fee_payer_keys.id ORDER BY height, sequence_no\n\
        \      "
    |> Caqti_request.exec Caqti_type.unit

  let dump_user_commands (module Conn : CONNECTION) output_file =
    Conn.exec (dump_user_commands_query ~output_file) ()

  let dump_internal_commands_query ~output_file =
    dump_sql_to_csv output_file
      ~sql:
        (Printf.sprintf
           "WITH internal_command_ids AS \n\
           \        ( SELECT internal_command_id, height, sequence_no, \
            secondary_sequence_no FROM blocks_internal_commands \n\
           \          INNER JOIN blocks ON blocks.id = block_id \n\
           \          WHERE chain_status = 'canonical'\n\
           \        ) \n\
           \        SELECT receiver_keys.value, fee, sequence_no, \
            secondary_sequence_no, hash FROM internal_commands \n\
           \        INNER JOIN internal_command_ids ON internal_command_id = id\n\
           \        INNER JOIN public_keys AS receiver_keys  ON receiver_id  = \
            receiver_keys.id\n\
           \        ORDER BY height, sequence_no, secondary_sequence_no, type \n\
           \   \n\
           \          " )
    |> Caqti_request.exec Caqti_type.unit

  let dump_internal_commands (module Conn : CONNECTION) output_file =
    Conn.exec (dump_internal_commands_query ~output_file) ()

  let mark_chain_till_fork_block_as_canonical_query =
    Caqti_request.exec Caqti_type.string
      {sql|
      UPDATE blocks
    Set chain_status = 'canonical'
    WHERE id in 
      ( WITH RECURSIVE chain AS (
        SELECT id, parent_id, height, state_hash
        FROM blocks WHERE state_hash = $1
      
        UNION ALL
      
        SELECT b.id, b.parent_id, b.height, b.state_hash
        FROM blocks b
      
        INNER JOIN chain
      
        ON b.id = chain.parent_id AND (chain.height <> 1 OR b.state_hash = $1)
      
        ) SELECT id FROM chain ORDER BY height ASC
      )
      |sql}

  let mark_chain_till_fork_block_as_canonical (module Conn : CONNECTION)
      fork_state_hash =
    Conn.exec mark_chain_till_fork_block_as_canonical_query fork_state_hash
end

module Berkeley = struct
  let height_query =
    Caqti_request.find Caqti_type.unit Caqti_type.int
      {sql| 
            SELECT height from blocks order by height desc limit 1;
          |sql}

  let block_height (module Conn : CONNECTION) = Conn.find height_query ()

  let canonical_blocks_count_till_height_query =
    Caqti_request.find Caqti_type.int Caqti_type.int
      {sql|
        WITH RECURSIVE chain AS 
        (  
          SELECT id, parent_id, chain_status FROM blocks 
          WHERE height = ? AND chain_status = 'canonical' 
          
          UNION ALL 

          SELECT b.id, b.parent_id, b.chain_status FROM blocks b
          INNER JOIN chain ON b.id = chain.parent_id AND (chain.id <> 0 OR b.id = 0)
        ) SELECT count(*) FROM chain where chain_status = 'canonical';
      |sql}

  let canonical_blocks_count_till_height (module Conn : CONNECTION) height =
    Conn.find canonical_blocks_count_till_height_query height

  let blocks_count_query =
    Caqti_request.find Caqti_type.unit Caqti_type.int
      {sql|
          SELECT count(*) FROM blocks ;
        |sql}

  let blocks_count (module Conn : CONNECTION) = Conn.find blocks_count_query ()

  let dump_user_commands_till_height_query ~output_file ~height =
    dump_sql_to_csv output_file
      ~sql:
        (Printf.sprintf
           "WITH user_command_ids AS\n\
           \      ( SELECT height, sequence_no, user_command_id FROM \
            blocks_user_commands\n\
           \        INNER JOIN blocks ON blocks.id = block_id\n\
           \        WHERE chain_status = 'canonical'\n\
           \        AND height <= %d\n\
           \      )\n\
           \      SELECT receiver_keys.value, fee_payer_keys.value, nonce, \
            amount, fee, valid_until, memo, hash FROM user_commands\n\
           \      INNER JOIN user_command_ids ON user_command_id = id\n\
           \      INNER JOIN public_keys AS receiver_keys  ON receiver_id  = \
            receiver_keys.id\n\
           \      INNER JOIN public_keys AS fee_payer_keys ON fee_payer_id = \
            fee_payer_keys.id ORDER BY height, sequence_no\n\
           \     " height )
    |> Caqti_request.exec Caqti_type.unit

  let dump_user_commands_till_height (module Conn : CONNECTION) output_file
      height =
    Conn.exec (dump_user_commands_till_height_query ~output_file ~height) ()

  let dump_internal_commands_till_height_query ~output_file ~height =
    dump_sql_to_csv output_file
      ~sql:
        (Printf.sprintf
           "WITH internal_command_ids AS \n\
           \        ( SELECT internal_command_id, height, sequence_no, \
            secondary_sequence_no FROM blocks_internal_commands \n\
           \          INNER JOIN blocks ON blocks.id = block_id \n\
           \          WHERE chain_status = 'canonical'\n\
           \          AND height <= %d\n\
           \        ) \n\
           \        SELECT receiver_keys.value, fee, sequence_no, \
            secondary_sequence_no, hash FROM internal_commands \n\
           \        INNER JOIN internal_command_ids ON internal_command_id = id\n\
           \        INNER JOIN public_keys AS receiver_keys  ON receiver_id  = \
            receiver_keys.id\n\
           \        ORDER BY height, sequence_no, secondary_sequence_no, \
            command_type \n\
           \      " height )
    |> Caqti_request.exec Caqti_type.unit

  let dump_internal_commands_till_height (module Conn : CONNECTION) output_file
      height =
    Conn.exec (dump_internal_commands_till_height_query ~output_file ~height) ()

  let dump_user_commands_query ~output_file =
    dump_sql_to_csv output_file
      ~sql:
        "WITH user_command_ids AS\n\
        \      ( SELECT height, sequence_no, user_command_id FROM \
         blocks_user_commands\n\
        \        INNER JOIN blocks ON blocks.id = block_id\n\
        \        WHERE chain_status = 'canonical'\n\
        \      )\n\
        \      SELECT receiver_keys.value, fee_payer_keys.value, nonce, \
         amount, fee, valid_until, memo, hash FROM user_commands\n\
        \      INNER JOIN user_command_ids ON user_command_id = id\n\
        \      INNER JOIN public_keys AS receiver_keys  ON receiver_id  = \
         receiver_keys.id\n\
        \      INNER JOIN public_keys AS fee_payer_keys ON fee_payer_id = \
         fee_payer_keys.id ORDER BY height, sequence_no\n\
        \     "
    |> Caqti_request.exec Caqti_type.unit

  let dump_user_commands (module Conn : CONNECTION) output_file =
    Conn.exec (dump_user_commands_query ~output_file) ()

  let dump_internal_commands_query ~output_file =
    dump_sql_to_csv output_file
      ~sql:
        "WITH internal_command_ids AS \n\
        \        ( SELECT internal_command_id, height, sequence_no, \
         secondary_sequence_no FROM blocks_internal_commands \n\
        \          INNER JOIN blocks ON blocks.id = block_id \n\
        \          WHERE chain_status = 'canonical'\n\
        \        ) \n\
        \        SELECT receiver_keys.value, fee, sequence_no, \
         secondary_sequence_no, hash FROM internal_commands \n\
        \        INNER JOIN internal_command_ids ON internal_command_id = id\n\
        \        INNER JOIN public_keys AS receiver_keys  ON receiver_id  = \
         receiver_keys.id\n\
        \        ORDER BY height, sequence_no, secondary_sequence_no, \
         command_type \n\
        \      "
    |> Caqti_request.exec Caqti_type.unit

  let dump_internal_commands (module Conn : CONNECTION) output_file =
    Conn.exec (dump_internal_commands_query ~output_file) ()

  let dump_account_accessed_to_csv_query ~output_file =
    dump_sql_to_csv output_file
      ~sql:
        {sql| SELECT account_identifier_id AS id, block_id 
                 FROM accounts_accessed
                 JOIN blocks ON block_id = blocks.id
                 WHERE height <> 1
                 ORDER BY block_id, id |sql}
    |> Caqti_request.exec Caqti_type.unit

  let dump_accounts_accessed_to_csv (module Conn : CONNECTION) output_file =
    Conn.exec (dump_account_accessed_to_csv_query ~output_file) ()

  let dump_block_hashes_till_height_query ~output_file ~height =
    dump_sql_to_csv output_file
      ~sql:
        (Printf.sprintf
           "SELECT state_hash, ledger_hash FROM blocks \n\
           \    WHERE chain_status = 'canonical'\n\
           \    AND height <= %d ORDER BY height\n\
           \ \n\
           \     " height )
    |> Caqti_request.exec Caqti_type.unit

  let dump_block_hashes_till_height (module Conn : CONNECTION) output_file
      height =
    Conn.exec (dump_block_hashes_till_height_query ~output_file ~height) ()

  let dump_block_hashes_query ~output_file =
    dump_sql_to_csv output_file
      ~sql:
        "\n\
        \      SELECT state_hash, ledger_hash FROM blocks\n\
        \      WHERE chain_status = 'canonical'\n\
        \      ORDER BY height\n\
        \      "
    |> Caqti_request.exec Caqti_type.unit

  let dump_block_hashes (module Conn : CONNECTION) output_file =
    Conn.exec (dump_block_hashes_query ~output_file) ()

  let dump_user_and_internal_command_info_to_csv_query ~output_file =
    dump_sql_to_csv output_file
      ~sql:
        {sql| 
      ( 
        WITH user_command_ids AS
        ( SELECT user_command_id, block_id, status FROM blocks_user_commands
          INNER JOIN blocks ON id = block_id
          WHERE chain_status = 'canonical'
        )
        SELECT account_identifiers.id, block_id FROM user_command_ids
        INNER JOIN user_commands ON id = user_command_id
        INNER JOIN account_identifiers ON (public_key_id = receiver_id AND status = 'applied')
                                       OR public_key_id = fee_payer_id 
      )
        UNION
      (
        WITH internal_command_ids AS
        ( SELECT internal_command_id, block_id FROM blocks_internal_commands
          INNER JOIN blocks ON id = block_id
          WHERE chain_status = 'canonical'
          AND status = 'applied'
        ) 
        SELECT account_identifiers.id, block_id FROM internal_command_ids
        INNER JOIN internal_commands ON id = internal_command_id
        INNER JOIN account_identifiers ON public_key_id = receiver_id
      ) ORDER BY block_id, id |sql}
    |> Caqti_request.exec Caqti_type.unit

  let dump_user_and_internal_command_info_to_csv (module Conn : CONNECTION)
      output_file =
    Conn.exec (dump_user_and_internal_command_info_to_csv_query ~output_file) ()

  let get_account_accessed_count_query =
    Caqti_request.find Caqti_type.unit Caqti_type.int
      {sql| SELECT count(*) FROM accounts_accessed; |sql}

  let count_account_accessed (module Conn : CONNECTION) =
    Conn.find get_account_accessed_count_query ()

  let get_account_id_accessed_in_commands_query =
    Caqti_request.find Caqti_type.unit Caqti_type.int
      {sql| 
        select count(distinct ids.account_identifier_id) FROM 

        ( 
          select distinct account_identifier_id from accounts_accessed where account_identifier_id in 
                ( select a.id from account_identifiers a inner join user_commands 
                on public_key_id = fee_payer_id 
                OR public_key_id = receiver_id 
                OR public_key_id = source_id
              )
              
              UNION ALL 
        
          select distinct account_identifier_id from accounts_accessed where account_identifier_id in 
                      (  select a.id from account_identifiers a inner join internal_commands 
                        on public_key_id = receiver_id
                      )
        ) as ids
     
      |sql}

  let get_account_id_accessed_in_commands (module Conn : CONNECTION) =
    Conn.find get_account_id_accessed_in_commands_query ()
end
