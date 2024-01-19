open Caqti_async

module Common = struct
  let block_state_hashes_query =
    Caqti_request.collect Caqti_type.int
      Caqti_type.(tup2 string string)
      {sql| 
            SELECT state_hash,parent_hash FROM blocks 
            WHERE chain_status <> 'orphaned'
            AND global_slot_since_genesis < ?
          |sql}

  let block_state_hashes (module Conn : CONNECTION) end_global_slot =
    Conn.collect_list block_state_hashes_query end_global_slot
end

module Mainnet = struct
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
          WHERE state_hash = ? and chain_status <> 'orphaned'
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
                  and chain_status <> 'orphaned' 
          |sql}

  let user_commands_hashes_query =
    Caqti_request.collect Caqti_type.int Caqti_type.string
      {sql| select hash from blocks_user_commands 
                  inner join blocks on blocks.id = blocks_user_commands.block_id 
                  inner join user_commands on user_commands.id = blocks_user_commands.user_command_id 
                  where global_slot_since_genesis < ? 
                  and chain_status <> 'orphaned' 
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
  let find_internal_command_id_by_hash_query =
    Caqti_request.find_opt Caqti_type.string Caqti_type.int
      {sql| select id 
            from internal_commands 
            where hash = ?    
          |sql}

  let find_internal_command_id_by_hash (module Conn : CONNECTION) hash =
    Conn.find_opt find_internal_command_id_by_hash_query hash

  let find_user_command_id_by_hash_query =
    Caqti_request.find_opt Caqti_type.string Caqti_type.int
      {sql| select id 
            from user_commands 
            where hash = ?
          |sql}

  let find_user_command_id_by_hash (module Conn : CONNECTION) hash =
    Conn.find_opt find_user_command_id_by_hash_query hash

  let find_block_by_state_hash_query =
    Caqti_request.find_opt Caqti_type.string Caqti_type.int
      {sql| select id 
            from blocks 
            where state_hash = ?
          |sql}

  let find_block_by_state_hash (module Conn : CONNECTION) hash =
    Conn.find_opt find_block_by_state_hash_query hash

  let find_block_by_parent_hash_query =
    Caqti_request.find_opt Caqti_type.string Caqti_type.int
      {sql| select id 
            from blocks 
            where parent_hash = ?
            limit 1
          |sql}

  let find_block_by_parent_hash (module Conn : CONNECTION) hash =
    Conn.find_opt find_block_by_parent_hash_query hash

  let find_block_by_ledger_hash_query =
    Caqti_request.find_opt Caqti_type.string Caqti_type.int
      {sql| select id 
            from blocks 
            where ledger_hash = ?
          |sql}

  let find_block_by_ledger_hash (module Conn : CONNECTION) hash =
    Conn.find_opt find_block_by_ledger_hash_query hash

  let count_pending_blocks_query =
    Caqti_request.find Caqti_type.string Caqti_type.int
      {sql| select count(*) from blocks 
            where chain_status = 'pending'
      |sql}

  let count_orphaned_blocks_query =
    Caqti_request.find Caqti_type.string Caqti_type.int
      {sql| select count(*) from blocks 
            where chain_status = 'orphaned'
      |sql}

  let count_pending_blocks (module Conn : CONNECTION) =
    Conn.find count_pending_blocks_query "pending"

  let count_orphaned_blocks (module Conn : CONNECTION) =
    Conn.find count_orphaned_blocks_query "orphaned"
end
