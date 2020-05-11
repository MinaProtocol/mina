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

let calculateProperty = (f, blocks) => {
  blocks
  |> Array.fold_left((map, block) => {f(map, block)}, StringMap.empty);
};

let incrementMapValue = (key, map) => {
  map
  |> StringMap.update(key, value => {
       switch (value) {
       | Some(valueCount) => Some(valueCount + 1)
       | None => Some(1)
       }
     });
};

let getBlocksCreatedByUser = blocks => {
  blocks
  |> Array.fold_left(
       (map, block: Types.NewBlock.data) => {
         incrementMapValue(block.creatorAccount.publicKey, map)
       },
       StringMap.empty,
     );
};

let calculateTransactionSent = (map, block: Types.NewBlock.data) => {
  block.transactions.userCommands
  |> Array.fold_left(
       (transactionMap, userCommand: Types.NewBlock.userCommands) => {
         incrementMapValue(userCommand.fromAccount.publicKey, transactionMap)
       },
       map,
     );
};

let getTransactionSentByUser = blocks => {
  blocks |> calculateProperty(calculateTransactionSent);
};

let calculateSnarkWorkCount = (map, block: Types.NewBlock.data) => {
  block.snarkJobs
  |> Array.fold_left(
       (snarkMap, snarkJob: Types.NewBlock.snarkJobs) => {
         incrementMapValue(snarkJob.prover, snarkMap)
       },
       map,
     );
};

let getSnarkWorkCreatedByUser = blocks => {
  blocks |> calculateProperty(calculateSnarkWorkCount);
};

let calculateAllUsers = metrics => {
  List.fold_left(
    StringMap.merge((_, _, _) => {Some()}),
    StringMap.empty,
    metrics,
  );
};

let calculateMetrics = blocks => {
  let blocksCreated = blocks |> getBlocksCreatedByUser;
  let transactionSent = blocks |> getTransactionSentByUser;
  let snarkWorkCreated = blocks |> getSnarkWorkCreatedByUser;
  let users = calculateAllUsers([blocksCreated, transactionSent]);

  StringMap.mapi(
    (key, _) =>
      {
        Types.Metrics.blocksCreated: StringMap.find_opt(key, blocksCreated),
        transactionSent: StringMap.find_opt(key, transactionSent),
        snarkWorkCreated: StringMap.find_opt(key, snarkWorkCreated),
      },
    users,
  );
};