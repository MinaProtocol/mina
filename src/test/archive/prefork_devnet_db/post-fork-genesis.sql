-- The mesa chain's genesis block on devnet, exactly as the archive recorded it.
--
-- Every value here is taken from the real devnet archive after the fork
-- (devnet-archive-dump-2026-08-20_0000): the block at height 545434 with
-- global_slot_since_hard_fork = 0, whose parent is the fork block
-- 3NLYmfj4U9Fbbvruz3QJj2j8WJyjhGtq4LgYvo7oW1WZm16uEKib.
--
-- It stands in for the post-fork daemon feeding this block to the archive,
-- which is how the archive really receives it.
--
-- Two things are deliberately not copied from that dump. Block ids are assigned
-- per archive instance and do not agree between the two dumps, so parent_id is
-- looked up here by the parent's state hash. And chain_status is 'pending'
-- rather than the 'canonical' the later dump shows, because pending is what a
-- freshly delivered block looks like; ordinary canonicalisation promotes it
-- once k blocks build on it.

-- The new era's protocol version. The pre-fork archive has only 2.0.0 and
-- 3.0.0; 4.0.0 arrives with the fork.
INSERT INTO protocol_versions (id, transaction, network, patch)
VALUES (3, 4, 0, 0)
ON CONFLICT DO NOTHING;

-- The ledger hashes the genesis block and its epoch data point at. All three
-- are new at the fork: the pre-fork archive stops at id 26622.
INSERT INTO snarked_ledger_hashes (id, value) VALUES
  (26623, 'jwrCSCRNpNx3ZBh6D4bUAnZtqPacKXXe6veGC9kQfHrxWqmEbJS'),
  (26624, 'jwbFn9V1eyDa5AgLkHAwsVffHSjLLhfw8WpKYM6bJiKXb5Uhbti'),
  (26625, 'jxUYRdFcuDDMyEtRXkAEo74EFpFSAjcVf6pBX9j56siW7rFZFRq')
ON CONFLICT DO NOTHING;

-- The genesis block's staking and next epoch data, likewise new at the fork.
INSERT INTO epoch_data
  (id, seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint,
   epoch_length)
VALUES
  (635611, '2vamERQZWT1miAnrxLJsjPmZmoCSemrz9JugjN8weQJeqhU7ZD38', 26624,
   1582881647000001000,
   '3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x',
   '3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x', 1),
  (635612, '2vbN7KKU3m1KSaiDxRUk7nhSFuyv8V5vTb6surCdwNAn5S4AJYj4', 26625,
   1585748525000001000,
   '3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x',
   '3NLn5HcetnE5ZaiejeqNYoBNQ8SxogzXZ9EuVyC9eZtCZozoSyro', 2)
ON CONFLICT DO NOTHING;

-- The block itself. parent_id and parent_hash come from the fork block as this
-- archive holds it, so the insert lands nothing at all if that block is absent.
INSERT INTO blocks
  (id, state_hash, parent_id, parent_hash, creator_id, block_winner_id,
   last_vrf_output, snarked_ledger_hash_id, staking_epoch_data_id,
   next_epoch_data_id, min_window_density, sub_window_densities,
   total_currency, ledger_hash, height, global_slot_since_hard_fork,
   global_slot_since_genesis, protocol_version_id, proposed_protocol_version_id,
   timestamp, chain_status)
SELECT
  688427, '3NLT7n4LiVo6U4LXr9BjCEp9712fP61uXkRC6hnRnB682A8f4HrJ',
  fork.id, fork.state_hash, 1, 1,
  'KB53dC2i5R27zxr9gUlOOWz5U5Dxluy9sL5-3Olahw4=',
  26623, 635611, 635612, 77,
  '{1,7,7,7,7,7,7,7,7,7,7}'::bigint[],
  1588907694000001000,
  'jwrCSCRNpNx3ZBh6D4bUAnZtqPacKXXe6veGC9kQfHrxWqmEbJS',
  545434, 0, 859560, 3, NULL,
  1787162400000, 'pending'::chain_status_type
FROM blocks fork
WHERE fork.state_hash = '3NLYmfj4U9Fbbvruz3QJj2j8WJyjhGtq4LgYvo7oW1WZm16uEKib';
