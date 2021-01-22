/*
  Metrics.re has the responsibilities of taking a collection of blocks as input
  and transforming that block data into a Map of public keys to metricRecord types.
  The metricRecord type is defined in Types/Metrics.

  The data visualized for a Map is as follows, where x is some int value:

 "public_key1": {
    blocksCreated: x,
    transactionSent: x,
    snarkFeesCollected: x,
    highestSnarkFeeCollected: x,
    transactionsReceivedByEcho: x,
    coinbaseReceiver: x,
    createAndSendToken: x,
 }

  All the metrics to be computed are specified in calculateMetrics(). Each
  metric to be computed is contained within it's own Map structure and is then
  combined together with all other metric Maps.
 */

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
  blocks->Belt.Array.keep((block: Types.Block.t) => {
    endTime < block.blockchainState.timestamp
    && block.blockchainState.timestamp > startTime
  });
};

// Gather metrics
let getBlocksCreatedByUser = blocks => {
  blocks
  |> Array.fold_left(
       (map, block: Types.Block.t) => {
         incrementMapValue(block.blockchainState.creatorAccount, map)
       },
       StringMap.empty,
     );
};

let calculateTransactionSent = (map, block: Types.Block.t) => {
  block.userCommands
  |> Array.fold_left(
       (transactionMap, userCommand: Types.Block.UserCommand.t) => {
         transactionMap
         |> StringMap.update(userCommand.fromAccount, value => {
              switch (value) {
              | Some(valueCount) =>
                let nonce = int_of_string(userCommand.nonce);
                nonce > valueCount ? Some(nonce) : Some(valueCount);
              | None => Some(0)
              }
            })
       },
       map,
     );
};

let getTransactionSentByUser = blocks => {
  blocks |> calculateProperty(calculateTransactionSent);
};

/*
  Due to snarkJobs not being apart of the archive API, we calculate
  snark fees differently in the meantime.

  Snark fees will be calculated by inspecting fees paid out to snark
  workers inside blocks. This means that if you get more than one
  snark work included in a block we will measure as the sum of all fees
  for the work that has been included.
 */
let calculateSnarkFeeSum = (map, block: Types.Block.t) => {
  let coinbaseReceiver =
    Belt.Option.getWithDefault(block.blockchainState.coinbaseReceiver, "");

  block.internalCommands
  |> Array.fold_left(
       (map, command: Types.Block.InternalCommand.t) => {
         switch (command.type_, command.receiverAccount !== coinbaseReceiver) {
         | (FeeTransfer, true) =>
           map
           |> StringMap.update(
                command.receiverAccount,
                feeSum => {
                  let snarkFee = Int64.of_string(command.fee);
                  switch (feeSum) {
                  | Some(feeSum) => Some(Int64.add(snarkFee, feeSum))
                  | None => Some(snarkFee)
                  };
                },
              )
         | _ => map
         }
       },
       map,
     );
};

let getSnarkFeesCollected = blocks => {
  blocks |> calculateProperty(calculateSnarkFeeSum);
};

let calculateHighestSnarkFeeCollected = (map, block: Types.Block.t) => {
  let coinbaseReceiver =
    Belt.Option.getWithDefault(block.blockchainState.coinbaseReceiver, "");

  block.internalCommands
  |> Array.fold_left(
       (map, command: Types.Block.InternalCommand.t) => {
         switch (command.type_, command.receiverAccount !== coinbaseReceiver) {
         | (FeeTransfer, true) =>
           map
           |> StringMap.update(
                command.receiverAccount,
                feeCount => {
                  let snarkFee = Int64.of_string(command.fee);
                  switch (feeCount) {
                  | Some(feeCount) => Some(max(snarkFee, feeCount))
                  | None => Some(snarkFee)
                  };
                },
              )
         | _ => map
         }
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
       (map, block: Types.Block.t) => {
         block.userCommands
         |> Array.fold_left(
              (map, userCommand: Types.Block.UserCommand.t) => {
                addresses
                |> List.filter(address => {userCommand.toAccount === address})
                |> List.length > 0
                  ? incrementMapValue(userCommand.fromAccount, map) : map
              },
              map,
            )
       },
       StringMap.empty,
     );
};

let calculateCoinbaseReceiverChallenge = (map, block: Types.Block.t) => {
  block.internalCommands
  |> Array.fold_left(
       (map, command: Types.Block.InternalCommand.t) => {
         switch (command.type_) {
         | Coinbase =>
           StringMap.update(
             command.receiverAccount,
             _ =>
               Some(
                 command.receiverAccount
                 != block.blockchainState.creatorAccount,
               ),
             map,
           )
         | _ => map
         }
       },
       map,
     );
};

let getCoinbaseReceiverChallenge = blocks => {
  blocks |> calculateProperty(calculateCoinbaseReceiverChallenge);
};

let throwAwayValues = metrics => {
  metrics |> StringMap.map(_ => {()});
};

let calculateAllUsers = metrics => {
  metrics
  |> List.fold_left(StringMap.merge((_, _, _) => {Some()}), StringMap.empty);
};

let echoBotPublicKeys = [
  "B62qndJi5mnRoBZ8SAYDM1oR2SgAk5WpZC8hGpJUZ4e64kDHGbFMeLJ",
];

let excludePublicKeys = [];

let calculateMetrics = blocks => {
  let blocksCreated = getBlocksCreatedByUser(blocks);
  let transactionSent = getTransactionSentByUser(blocks);
  let snarkFeesCollected = getSnarkFeesCollected(blocks);
  let highestSnarkFeeCollected = StringMap.empty;
  let transactionsReceivedByEcho = StringMap.empty;
  let coinbaseReceiverChallenge = StringMap.empty;

  calculateAllUsers([
    throwAwayValues(blocksCreated),
    throwAwayValues(transactionSent),
    throwAwayValues(snarkFeesCollected),
  ])
  |> StringMap.filter((key, _) => {!List.mem(key, excludePublicKeys)})
  |> StringMap.mapi((key, _) =>
       {
         Types.Metrics.blocksCreated: StringMap.find_opt(key, blocksCreated),
         transactionSent: StringMap.find_opt(key, transactionSent),
         snarkFeesCollected: StringMap.find_opt(key, snarkFeesCollected),
         highestSnarkFeeCollected:
           StringMap.find_opt(key, highestSnarkFeeCollected),
         transactionsReceivedByEcho:
           StringMap.find_opt(key, transactionsReceivedByEcho),
         coinbaseReceiver: StringMap.find_opt(key, coinbaseReceiverChallenge),
       }
     );
};
