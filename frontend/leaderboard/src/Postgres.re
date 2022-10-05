open Bindings.Postgres;

let getUsers = "SELECT * FROM public_keys";

let getBlocksChallenge = pk => {
  {j|
    SELECT COUNT(*)
    FROM
      (SELECT DISTINCT ON (global_slot) global_slot, state_hash
      FROM blocks
      INNER JOIN public_keys AS p ON creator_id=p.id
      WHERE p.value = '$(pk)') AS blocksCreated
  |j};
};

let getTransactionsSentChallenge = pk => {
  {j|
    SELECT MAX(nonce)
    FROM user_commands
    INNER JOIN public_keys AS p ON source_id=p.id
    WHERE status = 'applied'
    AND type = 'payment'
    AND p.value = '$(pk)'
  |j};
};

let getSnarkFeeChallenge = pk => {
  {j|
    SELECT SUM(fee)
    FROM internal_commands as ic
    INNER JOIN blocks_internal_commands as bic ON bic.internal_command_id=ic.id
    INNER JOIN blocks as b ON b.id = bic.block_id
    INNER JOIN public_keys as p ON p.id=ic.receiver_id
    WHERE type = 'fee_transfer'
    AND value = '$(pk)'
    AND b.id NOT IN
    (
      SELECT b.id
      FROM internal_commands as ic
      INNER JOIN blocks_internal_commands as bic ON bic.internal_command_id=ic.id
      INNER JOIN blocks as b ON b.id = bic.block_id
      INNER JOIN public_keys as p ON p.id=ic.receiver_id
      WHERE type = 'coinbase'
      AND value = '$(pk)'
    )
  |j};
};

let getBlockHeight = "SELECT MAX(height) FROM blocks";

let createPool = pgConn => {
  makePool({connectionString: pgConn, connectionTimeoutMillis: 900000});
};

let endPool = pool => {
  endPool(pool);
};

let makeQuery = (pool, queryText) => {
  Js.Promise.make((~resolve, ~reject) => {
    query(pool, queryText, (~error, ~res) => {
      switch (Js.Nullable.toOption(error)) {
      | None => resolve(. res.rows)
      | Some(error) => reject(. failwith(error))
      }
    })
  });
};

let getColumn = (cell, columnName) => {
  Belt.Option.(
    Js.Json.(
      cell
      ->decodeObject
      ->flatMap(x => Js.Dict.get(x, columnName))
      ->flatMap(decodeString)
    )
  );
};

let getRow = (cell, columnName, index) => {
  Belt.Option.(
    Js.Json.(
      cell[index]
      ->decodeObject
      ->flatMap(x => Js.Dict.get(x, columnName))
      ->flatMap(decodeString)
    )
  );
};
