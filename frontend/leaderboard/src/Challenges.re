module StringMap = Map.Make(String);

let printMap = map => {
  StringMap.mapi(
    (key, value) => {
      Js.log(key);
      Js.log(value);
    },
    map,
  );
};

let getUsers = blocks => {
  Array.map(
    (block: Types.NewBlock.t) => block.data.newBlock.creatorAccount.publicKey,
    blocks,
  );
};

let calculateBlocksCreated = blocks => {
  printMap(
    Array.fold_left(
      (map, block: Types.NewBlock.t) => {
        StringMap.update(
          block.data.newBlock.creatorAccount.publicKey,
          value =>
            switch (value) {
            | Some(blockCount) => Some(blockCount + 1)
            | None => Some(1)
            },
          map,
        )
      },
      StringMap.empty,
      blocks,
    ),
  );
};

let calculateTransactionSent = blocks => {
  Js.log("calculateTransactionSent");
};

let calculateSnarkWorkCreated = blocks => {
  Js.log("calculateSnarkWorkCreated");
};

// Expected Output
// {
//       "pk1": {"block_count": 1, "transactions_sent": 134, "snark_jobs": 11}
//       "pk2": {"block_count": 4, "transactions_sent": 55, "snark_jobs": 3}
//       "pk3": {"block_count": 0, "transactions_sent": 3, "snark_jobs": 8}
//}
let handleMetrics = (metrics, blocks) => {
  Types.Metrics.(
    Array.map(
      metric => {
        switch (metric) {
        | BlocksCreated => blocks |> calculateBlocksCreated
        | _ => StringMap.empty
        }
      },
      metrics,
    )
  );
};