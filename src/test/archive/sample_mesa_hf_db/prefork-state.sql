-- Rebuild the pre-fork archive out of the fork-crossing fixture.
--
-- mesa_hf_dry_run_db.sql.tar.gz was dumped after the fork, so it holds both
-- eras: berkeley blocks up to height 1761 and mesa blocks from 1749. The
-- automode hand-over starts before any of the new era exists, so this removes
-- the new era and leaves the archive exactly as the pre-fork one held it at
-- chain end -- berkeley blocks only, the last of them stranded pending.
--
-- The post-fork genesis block is set aside rather than dropped. The test puts
-- it back unchanged, which is what the post-fork daemon does when it starts
-- feeding this archive.

CREATE TABLE IF NOT EXISTS saved_fork_genesis AS
  SELECT * FROM blocks
  WHERE protocol_version_id = 2 AND global_slot_since_hard_fork = 0;

CREATE TEMP TABLE new_era AS
  SELECT id FROM blocks WHERE protocol_version_id = 2;

DELETE FROM accounts_accessed        WHERE block_id IN (SELECT id FROM new_era);
DELETE FROM accounts_created         WHERE block_id IN (SELECT id FROM new_era);
DELETE FROM blocks_user_commands     WHERE block_id IN (SELECT id FROM new_era);
DELETE FROM blocks_internal_commands WHERE block_id IN (SELECT id FROM new_era);
DELETE FROM blocks_zkapp_commands    WHERE block_id IN (SELECT id FROM new_era);

-- Children first: blocks.parent_id points at blocks, so the era comes off from
-- its tip downwards, a layer at a time.
DO $$
DECLARE removed int;
BEGIN
  LOOP
    DELETE FROM blocks
    WHERE protocol_version_id = 2
      AND id NOT IN (SELECT parent_id FROM blocks WHERE parent_id IS NOT NULL);
    GET DIAGNOSTICS removed = ROW_COUNT;
    EXIT WHEN removed = 0;
  END LOOP;
END $$;

-- A pre-fork archive has no migration record at all. The upgrade script says so
-- itself, where it defaults a missing row to 3.0.0. Removing it puts the
-- archive back the way it was; it is not a way past the version guard.
DELETE FROM migration_history;
