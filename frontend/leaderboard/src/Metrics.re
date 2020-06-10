module StringMap = Map.Make(String);

// Helper functions for gathering metrics
let printMap = map => {
  map
  |> StringMap.mapi((key, value) => {
       Js.log(key);
       Js.log(value);
     });
};

// Iterate through list of blocks and apply f on all fields in a block
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

let max = (a, b) => {
  a > b ? a : b;
};

let filterBlocksByTimeWindow = (startTime, endTime, blocks) => {
  Array.to_list(blocks)
  |> List.filter((block: Types.NewBlock.data) => {
       endTime < block.protocolState.date
       && block.protocolState.date > startTime
     })
  |> Array.of_list;
};

// Gather metrics
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

let calculateSnarkFeeCount = (map, block: Types.NewBlock.data) => {
  block.snarkJobs
  |> Array.fold_left(
       (map, snarkJob: Types.NewBlock.snarkJobs) => {
         StringMap.update(
           snarkJob.prover,
           feeCount =>
             switch (feeCount) {
             | Some(feeCount) => Some(Int64.add(feeCount, snarkJob.fee))
             | None => Some(snarkJob.fee)
             },
           map,
         )
       },
       map,
     );
};

let getSnarkFeesCollected = blocks => {
  blocks |> calculateProperty(calculateSnarkFeeCount);
};

let calculateHighestSnarkFeeCollected = (map, block: Types.NewBlock.data) => {
  block.snarkJobs
  |> Array.fold_left(
       (map, snarkJob: Types.NewBlock.snarkJobs) => {
         StringMap.update(
           snarkJob.prover,
           feeCount =>
             switch (feeCount) {
             | Some(feeCount) => Some(max(feeCount, snarkJob.fee))
             | None => Some(snarkJob.fee)
             },
           map,
         )
       },
       map,
     );
};

let getHighestSnarkFeeCollected = blocks => {
  blocks |> calculateProperty(calculateHighestSnarkFeeCollected);
};

let getTransactionsSentToAddress = (blocks, addresses) => {
  blocks
  |> Array.fold_left(
       (map, block: Types.NewBlock.data) => {
         block.transactions.userCommands
         |> Array.fold_left(
              (map, userCommand: Types.NewBlock.userCommands) => {
                addresses
                |> List.filter(address => {
                     userCommand.toAccount.publicKey === address
                   })
                |> List.length > 0
                  ? incrementMapValue(userCommand.fromAccount.publicKey, map)
                  : map
              },
              map,
            )
       },
       StringMap.empty,
     );
};

let getCoinbaseReceiverChallenge = blocks => {
  blocks
  |> Array.fold_left(
       (map, block: Types.NewBlock.data) => {
         let creatorAccount = block.creatorAccount.publicKey;
         switch (
           Js.Nullable.toOption(block.transactions.coinbaseReceiverAccount)
         ) {
         | Some(account) =>
           StringMap.update(
             block.creatorAccount.publicKey,
             _ => Some(account.publicKey !== creatorAccount),
             map,
           )
         | None => map
         };
       },
       StringMap.empty,
     );
};

let throwAwayValues = metric => {
  StringMap.map(_ => {()}, metric);
};

let calculateAllUsers = metrics => {
  List.fold_left(
    StringMap.merge((_, _, _) => {Some()}),
    StringMap.empty,
    metrics,
  );
};

let echoBotPublicKeys = [
  "4vsRCVNep7JaFhtySu6vZCjnArvoAhkRscTy5TQsGTsKM4tJcYVc3uNUMRxQZAwVzSvkHDGWBmvhFpmCeiPASGnByXqvKzmHt4aR5uAWAQf3kqhwDJ2ZY3Hw4Dzo6awnJkxY338GEp12LE4x",
  "4vsRCViQQRxXfkgEspR9vPWLypuSEGkZtHxjYF7srq5M1mZN4LSoX7wWCFZGitJLmdoozDXmrCugvBBKsePd6hfBAp9P3eTCHs5HwdC763A1FbjzskfrCvWMq9KXXsmFxWhYpG9nnhWzqSC1",
];
let calculateMetrics = blocks => {
  let blocksCreated = getBlocksCreatedByUser(blocks);
  let transactionSent = getTransactionSentByUser(blocks);
  let snarkWorkCreated = getSnarkWorkCreatedByUser(blocks);
  let snarkFeesCollected = getSnarkFeesCollected(blocks);
  let highestSnarkFeeCollected = getHighestSnarkFeeCollected(blocks);
  let transactionsReceivedByEcho =
    getTransactionsSentToAddress(blocks, echoBotPublicKeys);
  let coinbaseReceiverChallenge = getCoinbaseReceiverChallenge(blocks);

  calculateAllUsers([
    throwAwayValues(blocksCreated),
    throwAwayValues(transactionSent),
    throwAwayValues(snarkWorkCreated),
    throwAwayValues(snarkFeesCollected),
    throwAwayValues(highestSnarkFeeCollected),
    throwAwayValues(transactionsReceivedByEcho),
    throwAwayValues(coinbaseReceiverChallenge),
  ])
  |> StringMap.mapi((key, _) =>
       {
         Types.Metrics.blocksCreated: StringMap.find_opt(key, blocksCreated),
         transactionSent: StringMap.find_opt(key, transactionSent),
         snarkWorkCreated: StringMap.find_opt(key, snarkWorkCreated),
         snarkFeesCollected: StringMap.find_opt(key, snarkFeesCollected),
         highestSnarkFeeCollected:
           StringMap.find_opt(key, highestSnarkFeeCollected),
         transactionsReceivedByEcho:
           StringMap.find_opt(key, transactionsReceivedByEcho),
         coinbaseReceiver: StringMap.find_opt(key, coinbaseReceiverChallenge),
       }
     );
};