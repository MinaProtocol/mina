open Bindings.Postgres;

let getUsers = "SELECT * FROM public_keys";

let getZkAppDeployedChallenge = pk => {
  {j|
      SELECT
        zvk.hash
      FROM
        account_identifiers as ai
        INNER JOIN public_keys as pk on pk.id = ai.public_key_id
        INNER JOIN accounts_accessed as aa ON aa.account_identifier_id = ai.id
        INNER JOIN zkapp_accounts as za ON za.id = aa.zkapp_id
        INNER JOIN zkapp_verification_keys as zvk ON zvk.id = za.verification_key_id
        AND pk.value = '$(pk)'
      WHERE
        zkapp_id is not null;
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
