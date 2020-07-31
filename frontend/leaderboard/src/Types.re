/* This module is just a copy so modifying the parsing doesn't break everything */
module Block = {
  // TODO: snarkJobs isn't implemented in the archive API yet
  // type snarkJobs = {
  //   prover: string,
  //   fee: string,
  // };

  type userCommand = {
    id: option(int),
    type_: option(string),
    fromAccount: option(string),
    toAccount: option(string),
    fee: option(int),
    amount: option(int),
  };

  type internalCommand = {
    id: option(int),
    type_: option(string),
    receiverAccount: option(string),
    fee: option(int),
    token: option(string),
  };

  type blockchainState = {
    timestamp: string,
    height: string,
  };

  type t = {
    id: int,
    blockchainState,
    creatorAccount: string,
    userCommands: array(userCommand),
    internalCommands: array(internalCommand),
    //snarkJobs: array(snarkJobs),
  };

  let addCommandIfExists = (command, commandId, commands) => {
    switch (commandId) {
    | Some(_) => Js.Array.push(command, commands) |> ignore
    | None => ()
    };
  };

  module Decode = {
    open Json.Decode;

    let blockchainState = json => {
      timestamp: json |> field("timestamp", string),
      height: json |> field("height", string),
    };

    let userCommand = json => {
      id: json |> optional(field("usercommandid", int)),
      type_: json |> optional(field("usercommandtype", string)),
      fromAccount: json |> optional(field("usercommandfromaccount", string)),
      toAccount: json |> optional(field("usercommandtoaccount", string)),
      fee: json |> optional(field("usercommandfee", int)),
      amount: json |> optional(field("usercommandamount", int)),
    };

    let internalCommand = json => {
      id: json |> optional(field("internalcommandid", int)),
      type_: json |> optional(field("internalcommandtype", string)),
      receiverAccount:
        json |> optional(field("internalcommandrecipient", string)),
      fee: json |> optional(field("internalcommandfee", int)),
      token: json |> optional(field("internalcommandtoken", string)),
    };

    let block = json => {
      id: json |> field("blockid", int),
      creatorAccount: json |> field("blockcreatoraccount", string),
      blockchainState: json |> blockchainState,
      userCommands: [||],
      internalCommands: [||],
    };
  };

  let decodeBlocks = blocks => {
    blocks
    |> Array.fold_left(
         (map, block) => {
           let newBlock = Decode.block(block);
           let userCommand = Decode.userCommand(block);
           let internalCommand = Decode.internalCommand(block);

           if (Belt.Map.Int.has(map, newBlock.id)) {
             Belt.Map.Int.update(map, newBlock.id, value => {
               Belt.Option.mapWithDefault(
                 value,
                 None,
                 currentBlock => {
                   addCommandIfExists(
                     userCommand,
                     userCommand.id,
                     currentBlock.userCommands,
                   );
                   addCommandIfExists(
                     internalCommand,
                     internalCommand.id,
                     currentBlock.internalCommands,
                   );
                   Some(currentBlock);
                 },
               )
             });
           } else {
             addCommandIfExists(
               userCommand,
               userCommand.id,
               newBlock.userCommands,
             );
             addCommandIfExists(
               internalCommand,
               internalCommand.id,
               newBlock.internalCommands,
             );
             Belt.Map.Int.set(map, newBlock.id, newBlock);
           };
         },
         Belt.Map.Int.empty,
       )
    |> Belt.Map.Int.valuesToArray;
  };
};

// TODO: replace this module
module NewBlock = {
  type account = {publicKey: string};

  type snarkJobs = {
    prover: string,
    fee: string,
  };

  type userCommands = {
    fromAccount: account,
    toAccount: account,
  };

  type feeTransfer = {
    fee: string,
    recipient: string,
  };
  type transactions = {
    userCommands: array(userCommands),
    feeTransfer: array(feeTransfer),
    coinbaseReceiverAccount: Js.Nullable.t(account),
  };

  type blockchainState = {date: string};

  type data = {
    creatorAccount: account,
    snarkJobs: array(snarkJobs),
    transactions,
    protocolState: blockchainState,
  };

  type newBlock = {newBlock: data};

  type t = {data: newBlock};

  external unsafeJSONToNewBlock: Js.Json.t => t = "%identity";
};

module Metrics = {
  type t =
    | BlocksCreated
    | TransactionsSent
    | SnarkWorkCreated
    | SnarkFeesCollected
    | HighestSnarkFeeCollected
    | TransactionsReceivedByEcho
    | CoinbaseReceiver;

  type metricRecord = {
    blocksCreated: option(int),
    transactionSent: option(int),
    snarkWorkCreated: option(int),
    snarkFeesCollected: option(int64),
    highestSnarkFeeCollected: option(int64),
    transactionsReceivedByEcho: option(int),
    coinbaseReceiver: option(bool),
  };
};