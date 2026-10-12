-- Deterministic synthetic chain for rosetta_search_bench.
--
-- Defaults: 50k accounts, 20k canonical blocks x 100 user commands = 2M user
-- commands, which is enough for an unindexed account lookup to cost seconds.
-- Accounts the bench queries are fixed by id:
--   1          busy:   fee payer of every 100th command (~20k)
--   2          medium: fee payer of every 5000th command (~400)
--   :accounts  sparse: receiver only, of exactly 3 applied commands
-- Every 20th command fails; every 50th height has an orphaned sibling block
-- that includes the same commands; 3 pending blocks sit above the canonical tip.

\set ON_ERROR_STOP on

\if :{?accounts} \else \set accounts 50000 \endif
\if :{?blocks} \else \set blocks 20000 \endif
\if :{?per_block} \else \set per_block 100 \endif

BEGIN;

INSERT INTO public_keys (id, value)
SELECT i, 'B62q' || substr(md5('pk' || i) || md5('pk-' || i), 1, 51)
FROM generate_series(1, :accounts) AS i;

INSERT INTO tokens (id, value)
VALUES (1, 'wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf');

INSERT INTO account_identifiers (id, public_key_id, token_id)
SELECT i, i, 1 FROM generate_series(1, :accounts) AS i;

INSERT INTO snarked_ledger_hashes (id, value) VALUES (1, 'jx-bench');

INSERT INTO epoch_data
  (id, seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint, epoch_length)
VALUES (1, 'seed-bench', 1, '0', 'start', 'lock', 1);

INSERT INTO protocol_versions (id, transaction, network, patch) VALUES (1, 4, 0, 0);

-- canonical chain: id = height
INSERT INTO blocks
  ( id, state_hash, parent_id, parent_hash, creator_id, block_winner_id
  , last_vrf_output, snarked_ledger_hash_id, staking_epoch_data_id
  , next_epoch_data_id, min_window_density, sub_window_densities
  , total_currency, ledger_hash, height, global_slot_since_hard_fork
  , global_slot_since_genesis, protocol_version_id, timestamp, chain_status )
SELECT h, '3N' || md5('b' || h), NULLIF(h - 1, 0), '3N' || md5('b' || (h - 1)),
       1 + h % 100, 1 + h % 100, 'vrf', 1, 1, 1, 0, '{}', '0', 'jx', h, h, h, 1,
       (h * 180000)::text, 'canonical'
FROM generate_series(1::bigint, :blocks) AS h;

-- orphaned siblings at every 50th height
INSERT INTO blocks
  ( id, state_hash, parent_id, parent_hash, creator_id, block_winner_id
  , last_vrf_output, snarked_ledger_hash_id, staking_epoch_data_id
  , next_epoch_data_id, min_window_density, sub_window_densities
  , total_currency, ledger_hash, height, global_slot_since_hard_fork
  , global_slot_since_genesis, protocol_version_id, timestamp, chain_status )
SELECT :blocks + h / 50, '3N' || md5('o' || h), NULLIF(h - 1, 0),
       '3N' || md5('b' || (h - 1)), 1 + h % 100, 1 + h % 100, 'vrf', 1, 1, 1, 0,
       '{}', '0', 'jx', h, h, h, 1, (h * 180000)::text, 'orphaned'
FROM generate_series(50::bigint, :blocks, 50) AS h;

-- pending blocks above the canonical tip
INSERT INTO blocks
  ( id, state_hash, parent_id, parent_hash, creator_id, block_winner_id
  , last_vrf_output, snarked_ledger_hash_id, staking_epoch_data_id
  , next_epoch_data_id, min_window_density, sub_window_densities
  , total_currency, ledger_hash, height, global_slot_since_hard_fork
  , global_slot_since_genesis, protocol_version_id, timestamp, chain_status )
SELECT :blocks + :blocks / 50 + p, '3N' || md5('p' || p), NULL,
       '3N' || md5('b' || (:blocks + p - 1)), 1, 1, 'vrf', 1, 1, 1, 0, '{}',
       '0', 'jx', :blocks + p, :blocks + p, :blocks + p, 1,
       ((:blocks + p) * 180000)::text, 'pending'
FROM generate_series(1::bigint, 3) AS p;

-- user commands: 1-based i, placed in canonical block (i-1)/per_block+1
INSERT INTO user_commands
  ( id, command_type, fee_payer_id, source_id, receiver_id, nonce, amount, fee
  , valid_until, memo, hash )
SELECT i,
       (CASE WHEN i % 50 = 0 THEN 'delegation' ELSE 'payment' END)::user_command_type,
       payer, payer,
       CASE WHEN i IN (n / 4 + 1, n / 2 + 1, 3 * n / 4 + 1) THEN :accounts
            ELSE 3 + (i * 104729) % (:accounts - 3) END,
       i, '1000000000', '10000000', NULL, '',
       'Ckp' || md5('uc' || i) || substr(md5('uc-' || i), 1, 17)
FROM (
  SELECT i, :blocks * :per_block AS n,
         CASE WHEN i % 100 = 0 THEN 1
              WHEN i % 5000 = 1 THEN 2
              ELSE 3 + (i * 7919) % (:accounts - 3) END AS payer
  FROM generate_series(1::bigint, :blocks * :per_block) AS i
) AS c;

INSERT INTO blocks_user_commands
  (block_id, user_command_id, sequence_no, status, failure_reason)
SELECT (i - 1) / :per_block + 1, i, (i - 1) % :per_block,
       (CASE WHEN i % 20 = 0 THEN 'failed' ELSE 'applied' END)::transaction_status,
       CASE WHEN i % 20 = 0 THEN 'Amount_insufficient_to_create_account' END
FROM generate_series(1::bigint, :blocks * :per_block) AS i;

-- orphaned siblings carry the same commands as their canonical height
INSERT INTO blocks_user_commands
  (block_id, user_command_id, sequence_no, status, failure_reason)
SELECT o.id, buc.user_command_id, buc.sequence_no, buc.status, buc.failure_reason
FROM blocks o
JOIN blocks_user_commands buc ON buc.block_id = o.height
WHERE o.chain_status = 'orphaned';

-- one coinbase per canonical block
INSERT INTO internal_commands (id, command_type, receiver_id, fee, hash)
SELECT h, 'coinbase', 1 + h % 100, '720000000000', 'Ckp' || md5('ic' || h)
FROM generate_series(1::bigint, :blocks) AS h;

INSERT INTO blocks_internal_commands
  (block_id, internal_command_id, sequence_no, secondary_sequence_no, status)
SELECT h, h, :per_block, 0, 'applied' FROM generate_series(1::bigint, :blocks) AS h;

-- every account is created once, spread over the chain
INSERT INTO accounts_created (block_id, account_identifier_id, creation_fee)
SELECT 1 + i % :blocks, i, '1000000000' FROM generate_series(1, :accounts) AS i;

COMMIT;

ANALYZE;
