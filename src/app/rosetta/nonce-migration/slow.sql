/* See comments on the above query to help understand this one.
 * Since this query acts on only canonical blocks, we can skip the
 * recursive traversal part. */
SELECT DISTINCT
  combo.pk_id,
  MIN(combo.block_global_slot_since_genesis) AS block_global_slot_since_genesis,
  MIN(combo.balance) AS balance,
  MIN(combo.nonce) AS nonce
FROM (
  (SELECT pks.id as pk_id,b.global_slot_since_genesis AS block_global_slot_since_genesis,balance,NULL AS nonce

  FROM blocks b
  INNER JOIN balances             bal  ON b.id = bal.block_id
  INNER JOIN public_keys          pks  ON bal.public_key_id = pks.id

  WHERE pks.value = '$1'
  AND b.height <= $2
  AND b.chain_status = 'canonical'

  ORDER BY (bal.block_height, bal.block_sequence_no, bal.block_secondary_sequence_no) DESC
  LIMIT 1)
  UNION ALL
  (SELECT pks.id,NULL,NULL,cmds.nonce

  FROM blocks b
  INNER JOIN blocks_user_commands busc ON busc.block_id = b.id
  INNER JOIN user_commands        cmds ON cmds.id = busc.user_command_id
  INNER JOIN public_keys          pks  ON pks.id = cmds.source_id

  WHERE pks.value = '$1'
  AND b.height <= $2
  AND b.chain_status = 'canonical'

  ORDER BY (b.height, busc.sequence_no) DESC
  LIMIT 1)
  )
AS combo GROUP BY combo.pk_id

