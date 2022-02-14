SELECT b.global_slot_since_genesis AS block_global_slot_since_genesis,balance,bal.nonce

FROM blocks b
INNER JOIN balances bal ON b.id = bal.block_id
INNER JOIN public_keys pks ON bal.public_key_id = pks.id

WHERE pks.value = '$1'
AND b.height <= $2
AND b.chain_status = 'canonical'

ORDER BY (bal.block_height, bal.block_sequence_no, bal.block_secondary_sequence_no) DESC
LIMIT 1

