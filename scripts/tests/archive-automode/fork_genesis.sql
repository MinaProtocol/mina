-- The post-fork chain's genesis block.
--
-- It sits one above the fork block and its parent hash is the fork block's, so
-- it is the chain's own confirmation of what the configuration asserted. The
-- repair waits for it: until it is here, the fork block is attested by a single
-- message and nothing corroborates it.
--
-- It also carries the new protocol version and global_slot_since_hard_fork = 0,
-- which is what makes it an era genesis and what bounds the orphaning.

INSERT INTO blocks
  (id, state_hash, parent_id, parent_hash, creator_id, block_winner_id,
   last_vrf_output, snarked_ledger_hash_id, staking_epoch_data_id,
   next_epoch_data_id, min_window_density, sub_window_densities,
   total_currency, ledger_hash, height, global_slot_since_hard_fork,
   global_slot_since_genesis, protocol_version_id, timestamp, chain_status)
VALUES
  (201, 'FORK_GENESIS', 10, 'B_010', 1, 1, 'vrf', 1, 1, 1, 77,
   ARRAY[7,7,7,7,7,7,7]::bigint[], '10000000000',
   'jxo5pSyt16XGwA9UeuAdiFDzrwFH3smbNTJF7fxq98w1y9Jem2m',
   11, 0, 20, 2, '1701262000', 'canonical'::chain_status_type);
