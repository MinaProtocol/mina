open Bindings.Postgres;

let getBlocks = "SELECT b.id AS blockid, uc.id AS userCommandId, ic.id AS internalCommandId, b.state_hash, pk1.value AS blockcreatorAccount, b.height, b.timestamp, ic.type AS internalCommandType, pk2.value AS internalCommandRecipient, ic.fee as internalCommandFee, ic.token AS internalCommandToken, uc.type AS userCommandType, uc.status AS userCommandStatus, uc.amount AS userCommandAmount, uc.fee AS userCommandFee, pk3.value AS userCommandFeePayerAccount, pk4.value AS userCommandFromAccount, pk5.value AS userCommandToAccount, uc.memo AS userCommandMemo

FROM blocks AS b

INNER JOIN public_keys AS pk1 ON b.creator_id = pk1.id

LEFT JOIN blocks_internal_commands AS bic ON b.id = bic.block_id
LEFT JOIN internal_commands AS ic ON ic.id = bic.internal_command_id

LEFT JOIN blocks_user_commands AS buc ON b.id = buc.block_id
LEFT JOIN user_commands AS uc ON uc.id = buc.user_command_id

LEFT JOIN public_keys AS pk2 ON ic.receiver_id = pk2.id
LEFT JOIN public_keys AS pk3 ON uc.fee_payer_id = pk3.id
LEFT JOIN public_keys AS pk4 ON uc.source_id = pk4.id
LEFT JOIN public_keys AS pk5 ON uc.receiver_id = pk5.id";

let createPool = pgConn => {
  makePool({connectionString: pgConn});
};

let endPool = pool => {
  endPool(pool);
};

let makeQuery = (pool, queryText, cb) => {
  query(pool, queryText, (~error, ~res) => {
    switch (Js.Nullable.toOption(error)) {
    | None => cb(Ok(res.rows))
    | Some(error) => cb(Error(error))
    }
  });
};
