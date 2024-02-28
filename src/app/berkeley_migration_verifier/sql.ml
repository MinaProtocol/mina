open Caqti_async

module Mainnet = struct
  let dump_state_and_ledger_hashes_to_csv_query ~output_file ~height =
    (* Workaround for replacing output file as caqti has an issue with using ? in place of FILE argument*)
    let sql =
      " \n\
      \      COPY \n\
      \    ( SELECT state_hash, ledger_hash FROM blocks \n\
      \      WHERE chain_status = 'canonical'\n\
      \      AND height <= HEIGHT ORDER BY height\n\
      \    ) TO 'OUTPUT' DELIMITER ',' CSV HEADER   \n\
      \    "
      |> Str.global_replace (Str.regexp_string "OUTPUT") output_file
      |> Str.global_replace (Str.regexp_string "HEIGHT") (Int.to_string height)
    in

    Caqti_request.exec Caqti_type.unit sql

  let dump_state_and_ledger_hashes_to_csv (module Conn : CONNECTION) output_file
      height =
    Conn.exec
      (dump_state_and_ledger_hashes_to_csv_query ~output_file ~height)
      ()

  let dump_user_command_info_to_csv_query ~output_file ~height =
    (* Workaround for replacing output file as caqti has an issue with using ? in place of FILE argument*)
    let sql =
      "\n\
      \    COPY\n\
      \    ( WITH user_command_ids AS \n\
      \      ( SELECT user_command_id FROM blocks_user_commands \n\
      \        INNER JOIN blocks ON blocks.id = block_id \n\
      \        WHERE chain_status = 'canonical' \n\
      \        AND height <= HEIGHT ORDER BY height, sequence_no \n\
      \      ) \n\
      \      SELECT receiver_keys.value, fee_payer_keys.value, nonce, amount, \
       fee, valid_until, memo, hash FROM user_commands \n\
      \      INNER JOIN user_command_ids ON user_command_id = id\n\
      \      INNER JOIN public_keys AS receiver_keys  ON receiver_id  = \
       receiver_keys.id\n\
      \      INNER JOIN public_keys AS fee_payer_keys ON fee_payer_id = \
       fee_payer_keys.id \n\
      \    ) TO 'OUTPUT' DELIMITER ',' CSV HEADER\n\
      \  "
      |> Str.global_replace (Str.regexp_string "OUTPUT") output_file
      |> Str.global_replace (Str.regexp_string "HEIGHT") (Int.to_string height)
    in

    Caqti_request.exec Caqti_type.unit sql

  let dump_user_command_info_to_csv (module Conn : CONNECTION) output_file
      height =
    Conn.exec (dump_user_command_info_to_csv_query ~output_file ~height) ()

  let dump_internal_command_info_to_csv_query ~output_file ~height =
    (* Workaround for replacing output file as caqti has an issue with using ? in place of FILE argument*)
    let sql =
      "\n\
      \      COPY\n\
      \      ( WITH internal_command_ids AS \n\
      \        ( SELECT internal_command_id, height, sequence_no, \
       secondary_sequence_no FROM blocks_internal_commands \n\
      \          INNER JOIN blocks ON blocks.id = block_id \n\
      \          WHERE chain_status = 'canonical'\n\
      \          AND height <= HEIGHT\n\
      \        ) \n\
      \        SELECT receiver_keys.value, fee, sequence_no, \
       secondary_sequence_no, hash FROM internal_commands \n\
      \        INNER JOIN internal_command_ids ON internal_command_id = id\n\
      \        INNER JOIN public_keys AS receiver_keys  ON receiver_id  = \
       receiver_keys.id\n\
      \        ORDER BY height, sequence_no, secondary_sequence_no, type \n\
      \      ) TO 'OUTPUT' DELIMITER ',' CSV HEADER\n\
      \    "
      |> Str.global_replace (Str.regexp_string "OUTPUT") output_file
      |> Str.global_replace (Str.regexp_string "HEIGHT") (Int.to_string height)
    in

    Caqti_request.exec Caqti_type.unit sql

  let dump_internal_command_info_to_csv (module Conn : CONNECTION) output_file
      height =
    Conn.exec (dump_internal_command_info_to_csv_query ~output_file ~height) ()

  let latest_state_hash_before_slot_query =
    Caqti_request.find_opt Caqti_type.int Caqti_type.string
      {sql| 
          SELECT state_hash FROM blocks WHERE global_slot_since_genesis < ?
                 and chain_status <> 'orphaned'
           ORDER BY global_slot_since_genesis desc LIMIT 1
          |sql}

  let latest_state_hash =
    Caqti_request.find_opt Caqti_type.unit Caqti_type.string
      {sql| 
          SELECT state_hash FROM blocks WHERE
                chain_status <> 'orphaned'
           ORDER BY global_slot_since_genesis desc LIMIT 1
          |sql}

  let blockchain_length_for_state_hash_query =
    Caqti_request.find_opt Caqti_type.string Caqti_type.int
      {sql| 
        SELECT height FROM blocks WHERE
              state_hash = ?
        |sql}

  let latest_canonical_state_hash_query =
    Caqti_request.find_opt Caqti_type.unit Caqti_type.string
      {sql| 
          SELECT state_hash FROM blocks WHERE
                chain_status = 'canonical'
           ORDER BY global_slot_since_genesis desc LIMIT 1
          |sql}

  let global_slot_since_genesis_at_state_hash_query =
    Caqti_request.find_opt Caqti_type.string Caqti_type.int
      {sql| 
          SELECT global_slot_since_genesis FROM blocks 
          WHERE state_hash = ?
          LIMIT 1
          |sql}

  let blockchain_length_for_state_hash (module Conn : CONNECTION) state_hash =
    Conn.find_opt blockchain_length_for_state_hash_query state_hash

  let global_slot_since_genesis_at_state_hash (module Conn : CONNECTION)
      state_hash =
    Conn.find_opt global_slot_since_genesis_at_state_hash_query state_hash

  let latest_state_hash_before_slot (module Conn : CONNECTION) slot =
    Conn.find_opt latest_state_hash_before_slot_query slot

  let latest_canonical_state_hash (module Conn : CONNECTION) =
    Conn.find_opt latest_canonical_state_hash_query ()

  let latest_state_hash (module Conn : CONNECTION) =
    Conn.find_opt latest_state_hash ()

  let max_length_query =
    Caqti_request.find_opt Caqti_type.unit Caqti_type.int64
      {sql| 
          SELECT height FROM blocks
          WHERE chain_status = 'pending'
          ORDER BY height
          DESC
          LIMIT 1
          |sql}

  let max_length (module Conn : CONNECTION) = Conn.find_opt max_length_query ()

  let max_state_hash_query =
    Caqti_request.find_opt Caqti_type.unit Caqti_type.string
      {sql| 
          SELECT state_hash FROM blocks
          WHERE chain_status = 'pending'
          ORDER BY height
          DESC
          LIMIT 1
        |sql}

  let max_state_hash (module Conn : CONNECTION) =
    Conn.find_opt max_state_hash_query ()

  let internal_commands_hashes_query =
    Caqti_request.collect Caqti_type.int Caqti_type.string
      {sql| select hash from blocks_internal_commands 
                  inner join blocks on blocks.id = blocks_internal_commands.block_id 
                  inner join internal_commands on internal_commands.id = blocks_internal_commands.internal_command_id 
                  where global_slot_since_genesis < ?
                  and chain_status = 'canonical' 
          |sql}

  let user_commands_hashes_query =
    Caqti_request.collect Caqti_type.int Caqti_type.string
      {sql| select hash from blocks_user_commands 
                  inner join blocks on blocks.id = blocks_user_commands.block_id 
                  inner join user_commands on user_commands.id = blocks_user_commands.user_command_id 
                  where global_slot_since_genesis < ? 
                  and chain_status = 'canonical' 
          |sql}

  let user_commands_hashes (module Conn : CONNECTION) end_global_slot =
    Conn.collect_list user_commands_hashes_query end_global_slot

  let internal_commands_hashes (module Conn : CONNECTION) end_global_slot =
    Conn.collect_list internal_commands_hashes_query end_global_slot

  let block_hashes_query =
    Caqti_request.collect Caqti_type.int Caqti_type.string
      {sql| select state_hash from blocks where global_slot_since_genesis < ? and chain_status = 'canonical' |sql}

  let block_parent_hashes_query =
    Caqti_request.collect Caqti_type.int Caqti_type.string
      {sql| select state_hash from blocks where global_slot_since_genesis < ? and state_hash is not null and chain_status = 'canonical'|sql}

  let ledger_hashes_query =
    Caqti_request.collect Caqti_type.int Caqti_type.string
      {sql| select ledger_hash from blocks where global_slot_since_genesis < ? and chain_status = 'canonical' |sql}

  let block_hashes_query_no_orphaned =
    Caqti_request.collect Caqti_type.int Caqti_type.string
      {sql| select state_hash from blocks 
            where global_slot_since_genesis < ? 
            and chain_status <> 'orphaned'
      |sql}

  let block_parent_hashes_query_no_orphaned =
    Caqti_request.collect Caqti_type.int Caqti_type.string
      {sql| select parent_hash from blocks 
            where global_slot_since_genesis < ? 
            and chain_status <> 'orphaned'    
            and parent_id is not null
      |sql}

  let ledger_hashes_query_no_orphaned =
    Caqti_request.collect Caqti_type.int Caqti_type.string
      {sql| select ledger_hash from blocks 
            where global_slot_since_genesis < ? 
            and chain_status <> 'orphaned' 
      |sql}

  let block_hashes_only_canonical (module Conn : CONNECTION) end_global_slot =
    Conn.collect_list block_hashes_query end_global_slot

  let block_parent_hashes_only_canonical (module Conn : CONNECTION)
      end_global_slot =
    Conn.collect_list block_parent_hashes_query end_global_slot

  let ledger_hashes_only_canonical (module Conn : CONNECTION) end_global_slot =
    Conn.collect_list ledger_hashes_query end_global_slot

  let block_hashes_no_orphaned (module Conn : CONNECTION) end_global_slot =
    Conn.collect_list block_hashes_query_no_orphaned end_global_slot

  let block_parent_hashes_no_orphaned (module Conn : CONNECTION) end_global_slot
      =
    Conn.collect_list block_parent_hashes_query_no_orphaned end_global_slot

  let ledger_hashes_no_orphaned (module Conn : CONNECTION) end_global_slot =
    Conn.collect_list ledger_hashes_query_no_orphaned end_global_slot
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

  let dump_internal_accounts_to_csv_query ~output_file =
    (* Workaround for replacing output file as caqti has an issue with using ? in place of FILE argument*)
    let sql =
      Str.global_replace
        (Str.regexp_string "OUTPUT")
        output_file
        "COPY\n\
        \      (\n\
        \        ( \n\
        \          WITH user_command_ids AS\n\
        \          ( SELECT user_command_id, block_id FROM blocks_user_commands\n\
        \            INNER JOIN blocks ON id = block_id\n\
        \            WHERE chain_status = 'canonical'\n\
        \          )\n\
        \          SELECT account_identifiers.id, block_id FROM user_command_ids\n\
        \          INNER JOIN user_commands ON id = user_command_id\n\
        \          INNER JOIN account_identifiers ON public_key_id = receiver_id\n\
        \                                        OR public_key_id = fee_payer_id\n\
        \        )\n\
        \          UNION\n\
        \        (\n\
        \          WITH internal_command_ids AS\n\
        \          ( SELECT internal_command_id, block_id FROM \
         blocks_internal_commands\n\
        \            INNER JOIN blocks ON id = block_id\n\
        \            WHERE chain_status = 'canonical'\n\
        \          ) \n\
        \          SELECT account_identifiers.id, block_id FROM \
         internal_command_ids\n\
        \          INNER JOIN internal_commands ON id = internal_command_id\n\
        \          INNER JOIN account_identifiers ON public_key_id = receiver_id\n\
        \        ) ORDER BY block_id, id\n\
        \      ) TO 'OUTPUT' DELIMITER ',' CSV HEADER\n\
        \    "
    in

    Caqti_request.exec Caqti_type.unit sql

  let dump_internal_accounts_to_csv (module Conn : CONNECTION) output_file =
    Conn.exec (dump_internal_accounts_to_csv_query ~output_file) ()

  let dump_account_accessed_to_csv_query ~output_file =
    (* Workaround for replacing output file as caqti has an issue with using ? in place of FILE argument*)
    let sql =
      Str.global_replace
        (Str.regexp_string "OUTPUT")
        output_file
        " \n\
        \          COPY\n\
        \          ( SELECT account_identifier_id AS id, block_id \n\
        \            FROM accounts_accessed \n\
        \            ORDER BY block_id, id \n\
        \          ) TO 'OUTPUT' DELIMITER ',' CSV HEADER\n\
        \        "
    in

    Caqti_request.exec Caqti_type.unit sql

  let dump_accounts_accessed_to_csv (module Conn : CONNECTION) output_file =
    Conn.exec (dump_account_accessed_to_csv_query ~output_file) ()

  let dump_state_and_ledger_hashes_to_csv_query ~output_file ~height =
    (* Workaround for replacing output file as caqti has an issue with using ? in place of FILE argument*)
    let sql =
      " \n\
      \    COPY \n\
      \  ( SELECT state_hash, ledger_hash FROM blocks \n\
      \    WHERE chain_status = 'canonical'\n\
      \    AND height <= HEIGHT ORDER BY height\n\
      \  ) TO 'OUTPUT' DELIMITER ',' CSV HEADER   \n\
      \  "
      |> Str.global_replace (Str.regexp_string "OUTPUT") output_file
      |> Str.global_replace (Str.regexp_string "HEIGHT") (Int.to_string height)
    in

    Caqti_request.exec Caqti_type.unit sql

  let dump_state_and_ledger_hashes_to_csv (module Conn : CONNECTION) output_file
      height =
    Conn.exec
      (dump_state_and_ledger_hashes_to_csv_query ~output_file ~height)
      ()

  let dump_user_command_info_to_csv_query ~output_file ~height =
    (* Workaround for replacing output file as caqti has an issue with using ? in place of FILE argument*)
    let sql =
      "\n\
      \    COPY\n\
      \    ( WITH user_command_ids AS \n\
      \      ( SELECT user_command_id FROM blocks_user_commands \n\
      \        INNER JOIN blocks ON blocks.id = block_id \n\
      \        WHERE chain_status = 'canonical' \n\
      \        AND height <= HEIGHT ORDER BY height, sequence_no \n\
      \      ) \n\
      \      SELECT receiver_keys.value, fee_payer_keys.value, nonce, amount, \
       fee, valid_until, memo, hash FROM user_commands \n\
      \      INNER JOIN user_command_ids ON user_command_id = id\n\
      \      INNER JOIN public_keys AS receiver_keys  ON receiver_id  = \
       receiver_keys.id\n\
      \      INNER JOIN public_keys AS fee_payer_keys ON fee_payer_id = \
       fee_payer_keys.id \n\
      \    ) TO 'OUTPUT' DELIMITER ',' CSV HEADER\n\
      \  "
      |> Str.global_replace (Str.regexp_string "OUTPUT") output_file
      |> Str.global_replace (Str.regexp_string "HEIGHT") (Int.to_string height)
    in

    Caqti_request.exec Caqti_type.unit sql

  let dump_user_command_info_to_csv (module Conn : CONNECTION) output_file
      height =
    Conn.exec (dump_user_command_info_to_csv_query ~output_file ~height) ()

  let dump_internal_command_info_to_csv_query ~output_file ~height =
    (* Workaround for replacing output file as caqti has an issue with using ? in place of FILE argument*)
    let sql =
      "\n\
      \    COPY\n\
      \    ( WITH internal_command_ids AS \n\
      \      ( SELECT internal_command_id, height, sequence_no, \
       secondary_sequence_no FROM blocks_internal_commands \n\
      \        INNER JOIN blocks ON blocks.id = block_id \n\
      \        WHERE chain_status = 'canonical'\n\
      \        AND height <= HEIGHT\n\
      \      ) \n\
      \      SELECT receiver_keys.value, fee, sequence_no, \
       secondary_sequence_no, hash FROM internal_commands \n\
      \      INNER JOIN internal_command_ids ON internal_command_id = id\n\
      \      INNER JOIN public_keys AS receiver_keys  ON receiver_id  = \
       receiver_keys.id\n\
      \      ORDER BY height, sequence_no, secondary_sequence_no, command_type \n\
      \    ) TO 'OUTPUT' DELIMITER ',' CSV HEADER\n\
      \  "
      |> Str.global_replace (Str.regexp_string "OUTPUT") output_file
      |> Str.global_replace (Str.regexp_string "HEIGHT") (Int.to_string height)
    in

    Caqti_request.exec Caqti_type.unit sql

  let dump_internal_command_info_to_csv (module Conn : CONNECTION) output_file
      height =
    Conn.exec (dump_user_command_info_to_csv_query ~output_file ~height) ()

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

  module Block_info = struct
    type t =
      { id : int
      ; parent_id : int
      ; global_slot_since_genesis : int64
      ; global_slot_since_hard_fork : int64
      ; state_hash : string
      ; height : int
      ; chain_status : string
      ; parent_hash : string
      ; ledger_hash : string
      ; protocol_version_id : int
      }
    [@@deriving hlist]

    let typ =
      Mina_caqti.Type_spec.custom_type ~to_hlist ~of_hlist
        Caqti_type.
          [ int; int; int64; int64; string; int; string; string; string; int ]

    (* find all blocks, working back from block with given state hash *)
    let forked_blockchain_query =
      Caqti_request.collect Caqti_type.string typ
        {sql| 
                      SELECT id, 
                             parent_id, 
                             global_slot_since_genesis, 
                             global_slot_since_hard_fork,
                             state_hash,
                             height,
                             chain_status,
                             parent_hash,
                             ledger_hash,
                             protocol_version_id
                      
                      FROM blocks
                      WHERE state_hash = ? or protocol_version_id = 2 
                      ORDER BY global_slot_since_genesis ASC
                  |sql}

    let forked_blockchain (module Conn : CONNECTION) forked_state =
      Conn.collect_list forked_blockchain_query forked_state
  end
end
