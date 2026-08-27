-- A chain for Rosetta to answer about.
--
-- Nothing here is about the fork boundary: this test only needs blocks that a
-- balance request can name, and an account that appears in none of them. It is
-- the same seed the archive automode harness uses, kept separately because that
-- harness arrives in a later change and a test should not reach across one.

BEGIN;

INSERT INTO public_keys (id, value) VALUES
  (1, 'B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg'),
  (2, 'B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g');

INSERT INTO snarked_ledger_hashes (id, value) VALUES
  (1, 'jxo5pSyt16XGwA9UeuAdiFDzrwFH3smbNTJF7fxq98w1y9Jem2m');

INSERT INTO epoch_data
  (id, seed, ledger_hash_id, total_currency, start_checkpoint,
   lock_checkpoint, epoch_length)
VALUES
  (1, '2vaRh7FQ5wSzmpFReF9gcRKjv48CcJvHs25aqb3SSZiPgHQBy5Dt', 1,
   '10000000000', 'CHECKPOINT_START', 'CHECKPOINT_LOCK', 1);

INSERT INTO protocol_versions (id, transaction, network, patch) VALUES
  (1, 3, 0, 0),   -- pre-fork
  (2, 4, 0, 0);   -- post-fork

-- The pre-fork chain. Heights 1..10 on the winning branch.
--
-- 1..5   already canonical: canonicalisation got this far before the chain
--        stopped, and nothing since has been able to advance it.
-- 6..10  pending, and stuck. 10 is the fork block.
INSERT INTO blocks
  (id, state_hash, parent_id, parent_hash, creator_id, block_winner_id,
   last_vrf_output, snarked_ledger_hash_id, staking_epoch_data_id,
   next_epoch_data_id, min_window_density, sub_window_densities,
   total_currency, ledger_hash, height, global_slot_since_hard_fork,
   global_slot_since_genesis, protocol_version_id, timestamp, chain_status)
SELECT
  h,
  'B_' || lpad(h::text, 3, '0'),
  CASE WHEN h = 1 THEN NULL ELSE h - 1 END,
  CASE WHEN h = 1 THEN 'GENESIS' ELSE 'B_' || lpad((h-1)::text, 3, '0') END,
  1, 1, 'vrf', 1, 1, 1, 77, ARRAY[7,7,7,7,7,7,7]::bigint[],
  '10000000000', 'jxo5pSyt16XGwA9UeuAdiFDzrwFH3smbNTJF7fxq98w1y9Jem2m',
  -- The era's genesis block is the one at global_slot_since_hard_fork = 0.
  -- The archive marks such a block canonical on insert, and the repair anchors
  -- on it, so the seed has to have one.
  h, h - 1, h, 1, (1700000000 + h * 180)::text,
  (CASE WHEN h <= 5 THEN 'canonical' ELSE 'pending' END)::chain_status_type
FROM generate_series(1, 10) AS h;

-- Off-chain siblings at heights 7 and 9: legitimately produced, lost the fork
-- race, and left pending because nothing ever orphaned them. The repair has to
-- mark these orphaned, not canonical.
INSERT INTO blocks
  (id, state_hash, parent_id, parent_hash, creator_id, block_winner_id,
   last_vrf_output, snarked_ledger_hash_id, staking_epoch_data_id,
   next_epoch_data_id, min_window_density, sub_window_densities,
   total_currency, ledger_hash, height, global_slot_since_hard_fork,
   global_slot_since_genesis, protocol_version_id, timestamp, chain_status)
VALUES
  (107, 'ORPHAN_007', 6, 'B_006', 2, 2, 'vrf', 1, 1, 1, 77,
   ARRAY[7,7,7,7,7,7,7]::bigint[], '10000000000',
   'jxo5pSyt16XGwA9UeuAdiFDzrwFH3smbNTJF7fxq98w1y9Jem2m',
   7, 6, 7, 1, '1701260000', 'pending'::chain_status_type),
  (109, 'ORPHAN_009', 8, 'B_008', 2, 2, 'vrf', 1, 1, 1, 77,
   ARRAY[7,7,7,7,7,7,7]::bigint[], '10000000000',
   'jxo5pSyt16XGwA9UeuAdiFDzrwFH3smbNTJF7fxq98w1y9Jem2m',
   9, 8, 9, 1, '1701260360', 'pending'::chain_status_type);

SELECT setval(pg_get_serial_sequence('blocks', 'id'), 200);
SELECT setval(pg_get_serial_sequence('public_keys', 'id'), 200);

COMMIT;
