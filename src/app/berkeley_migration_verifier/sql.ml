open Async
open Caqti_async

let dump_sql_to_csv_string ~sql =
  Printf.sprintf "COPY ( %s ) TO STDOUT DELIMITER ',' CSV HEADER " sql

module Mainnet = struct
  let dump_accounts_created_to_csv_query =
    dump_sql_to_csv_string
      ~sql:
        {sql|
      ( SELECT height, value AS public_key, state_hash, receiver_account_creation_fee_paid AS creation_fee
        FROM blocks_user_commands
        JOIN blocks          ON block_id = blocks.id AND chain_status = 'canonical'
        JOIN user_commands   ON user_command_id = user_commands.id
        JOIN public_keys     ON receiver_id     = public_keys.id
        WHERE receiver_account_creation_fee_paid IS NOT NULL
        AND   status = 'applied'
      )
      UNION
      (
        SELECT height, value AS public_key, state_hash, receiver_account_creation_fee_paid AS creation_fee
        FROM blocks_internal_commands
        JOIN blocks            ON block_id            = blocks.id AND chain_status = 'canonical'
        JOIN internal_commands ON internal_command_id = internal_commands.id
        JOIN public_keys       ON receiver_id         = public_keys.id
        WHERE receiver_account_creation_fee_paid IS NOT NULL
      ) 
      ORDER BY height, public_key |sql}
    |> Caqti_request.find Caqti_type.unit Caqti_type.string

  let dump_accounts_created_to_csv (module Conn : CONNECTION) output_file =
    let open Deferred.Result.Let_syntax in
    let%bind res = Conn.find (dump_accounts_created_to_csv_query) () in
    Writer.with_file output_file ~f:(fun writer -> return @@ Writer.write writer res)

  let dump_state_and_ledger_hashes_to_csv_query =
    (* Workaround for replacing output file as caqti has an issue with using ? in place of FILE argument*)
    dump_sql_to_csv_string
      ~sql:
        "  SELECT state_hash, ledger_hash FROM blocks\n\
        \            WHERE chain_status = 'canonical'\n\
        \          "
    |> Caqti_request.find Caqti_type.unit Caqti_type.string

  let dump_block_hashes_till_height_query ~height =
    dump_sql_to_csv_string
      ~sql:
        (Printf.sprintf
           "\n\
           \      SELECT state_hash, ledger_hash FROM blocks\n\
           \            WHERE chain_status = 'canonical'\n\
           \            AND height <= %d ORDER BY height\n\
           \      " height )
    |> Caqti_request.find Caqti_type.unit Caqti_type.string

  let dump_block_hashes_till_height (module Conn : CONNECTION) output_file
      height =
    let open Deferred.Result.Let_syntax in
    let%bind res =
      Conn.find (dump_block_hashes_till_height_query ~height) ()
    in
    Writer.with_file output_file ~f:(fun writer -> return @@ Writer.write writer res)

  let dump_block_hashes_query =
    dump_sql_to_csv_string
      ~sql:
        "\n\
        \      SELECT state_hash, ledger_hash FROM blocks\n\
        \            WHERE chain_status = 'canonical'\n\
        \            ORDER BY height\n\
        \      "
    |> Caqti_request.find Caqti_type.unit Caqti_type.string

  let dump_block_hashes (module Conn : CONNECTION) output_file =
    let open Deferred.Result.Let_syntax in
    let%bind res = Conn.find (dump_block_hashes_query) () in
    Writer.with_file output_file ~f:(fun writer -> return @@ Writer.write writer res)

  let dump_user_commands_till_height_query ~height =
    dump_sql_to_csv_string
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
    |> Caqti_request.find Caqti_type.unit Caqti_type.string

  let dump_user_commands_till_height (module Conn : CONNECTION) output_file
      height =
    let open Deferred.Result.Let_syntax in
    let%bind res =
      Conn.find (dump_user_commands_till_height_query ~height) ()
    in
    Writer.with_file output_file ~f:(fun writer -> return @@ Writer.write writer res)

  let dump_internal_commands_till_height_query ~height =
    dump_sql_to_csv_string
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
    |> Caqti_request.find Caqti_type.unit Caqti_type.string

  let dump_internal_commands_till_height (module Conn : CONNECTION) output_file
      height =
    let open Deferred.Result.Let_syntax in
    let%bind res =
      Conn.find
        (dump_internal_commands_till_height_query ~height)
        ()
    in
    Writer.with_file output_file ~f:(fun writer -> return @@ Writer.write writer res)

  let dump_user_commands_query =
    dump_sql_to_csv_string
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
    |> Caqti_request.find Caqti_type.unit Caqti_type.string

  let dump_user_commands (module Conn : CONNECTION) output_file =
    let open Deferred.Result.Let_syntax in
    let%bind res = Conn.find (dump_user_commands_query) () in
    Writer.with_file output_file ~f:(fun writer -> return @@ Writer.write writer res)

  let dump_internal_commands_query =
    dump_sql_to_csv_string
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
    |> Caqti_request.find Caqti_type.unit Caqti_type.string

  let dump_internal_commands (module Conn : CONNECTION) output_file =
    let open Deferred.Result.Let_syntax in
    let%bind res = Conn.find (dump_internal_commands_query) () in
    Writer.with_file output_file ~f:(fun writer -> return @@ Writer.write writer res)

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
  let dump_accounts_created_to_csv_query =
    dump_sql_to_csv_string
      ~sql:
        {sql|
      SELECT height, value AS public_key, state_hash, creation_fee
      FROM accounts_created
      JOIN blocks              ON block_id              = blocks.id
      JOIN account_identifiers ON account_identifier_id = account_identifiers.id 
      JOIN public_keys         ON public_key_id         = public_keys.id
      ORDER BY height, public_key |sql}
    |> Caqti_request.find Caqti_type.unit Caqti_type.string

  let dump_accounts_created_to_csv (module Conn : CONNECTION) output_file =
    let open Deferred.Result.Let_syntax in
    let%bind res = Conn.find (dump_accounts_created_to_csv_query) () in
    Writer.with_file output_file ~f:(fun writer -> return @@ Writer.write writer res)

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

  let dump_user_commands_till_height_query ~height =
    dump_sql_to_csv_string
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
    |> Caqti_request.find Caqti_type.unit Caqti_type.string

  let dump_user_commands_till_height (module Conn : CONNECTION) output_file
      height =
    let open Deferred.Result.Let_syntax in
    let%bind res =
      Conn.find (dump_user_commands_till_height_query ~height) ()
    in
    Writer.with_file output_file ~f:(fun writer -> return @@ Writer.write writer res)

  let dump_internal_commands_till_height_query ~height =
    dump_sql_to_csv_string
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
    |> Caqti_request.find Caqti_type.unit Caqti_type.string

  let dump_internal_commands_till_height (module Conn : CONNECTION) output_file
      height =
    let open Deferred.Result.Let_syntax in
    let%bind res =
      Conn.find
        (dump_internal_commands_till_height_query ~height)
        ()
    in
    Writer.with_file output_file ~f:(fun writer -> return @@ Writer.write writer res)

  let dump_user_commands_query =
    dump_sql_to_csv_string
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
    |> Caqti_request.find Caqti_type.unit Caqti_type.string

  let dump_user_commands (module Conn : CONNECTION) output_file =
    let open Deferred.Result.Let_syntax in
    let%bind res = Conn.find (dump_user_commands_query) () in
    Writer.with_file output_file ~f:(fun writer -> return @@ Writer.write writer res)

  let dump_internal_commands_query =
    dump_sql_to_csv_string
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
    |> Caqti_request.find Caqti_type.unit Caqti_type.string

  let dump_internal_commands (module Conn : CONNECTION) output_file =
    let open Deferred.Result.Let_syntax in
    let%bind res = Conn.find (dump_internal_commands_query) () in
    Writer.with_file output_file ~f:(fun writer -> return @@ Writer.write writer res)

  let dump_account_accessed_to_csv_query =
    dump_sql_to_csv_string
      ~sql:
        {sql| SELECT account_identifier_id AS id, block_id 
                 FROM accounts_accessed
                 JOIN blocks ON block_id = blocks.id
                 WHERE height <> 1
                 ORDER BY block_id, id |sql}
    |> Caqti_request.find Caqti_type.unit Caqti_type.string

  let dump_accounts_accessed_to_csv (module Conn : CONNECTION) output_file =
    let open Deferred.Result.Let_syntax in
    let%bind res = Conn.find (dump_account_accessed_to_csv_query) () in
    Writer.with_file output_file ~f:(fun writer -> return @@ Writer.write writer res)

  let dump_block_hashes_till_height_query ~height =
    dump_sql_to_csv_string
      ~sql:
        (Printf.sprintf
           "SELECT state_hash, ledger_hash FROM blocks \n\
           \    WHERE chain_status = 'canonical'\n\
           \    AND height <= %d ORDER BY height\n\
           \ \n\
           \     " height )
    |> Caqti_request.find Caqti_type.unit Caqti_type.string

  let dump_block_hashes_till_height (module Conn : CONNECTION) output_file
      height =
    let open Deferred.Result.Let_syntax in
    let%bind res =
      Conn.find (dump_block_hashes_till_height_query ~height) ()
    in
    Writer.with_file output_file ~f:(fun writer -> return @@ Writer.write writer res)

  let dump_block_hashes_query =
    dump_sql_to_csv_string
      ~sql:
        "\n\
        \      SELECT state_hash, ledger_hash FROM blocks\n\
        \      WHERE chain_status = 'canonical'\n\
        \      ORDER BY height\n\
        \      "
    |> Caqti_request.find Caqti_type.unit Caqti_type.string

  let dump_block_hashes (module Conn : CONNECTION) output_file =
    let open Deferred.Result.Let_syntax in
    let%bind res = Conn.find (dump_block_hashes_query) () in
    Writer.with_file output_file ~f:(fun writer -> return @@ Writer.write writer res)

  let dump_user_and_internal_command_info_to_csv_query =
    dump_sql_to_csv_string
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
    |> Caqti_request.find Caqti_type.unit Caqti_type.string

  let dump_user_and_internal_command_info_to_csv (module Conn : CONNECTION)
      output_file =
    let open Deferred.Result.Let_syntax in
    let%bind res =
      Conn.find
        (dump_user_and_internal_command_info_to_csv_query)
        ()
    in
    Writer.with_file output_file ~f:(fun writer -> return @@ Writer.write writer res)

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
