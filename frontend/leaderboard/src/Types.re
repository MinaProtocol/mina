/* This module is just a copy so modifying the parsing doesn't break everything */
module Block = {
  // TODO: snarkJobs isn't implemented in the archive API yet
  // type snarkJobs = {
  //   prover: string,
  //   fee: string,
  // };

  type userCommand = {
    type_: option(string),
    fromAccount: option(string),
    toAccount: option(string),
    fee: option(int),
    amount: option(int),
  };

  type internalCommand = {
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
    blockId: int,
    blockchainState,
    creatorAccount: string,
    userCommands: array(userCommand),
    internalCommands: array(internalCommand),
    //snarkJobs: array(snarkJobs),
  };

  module Decode = {
    open Json.Decode;

    let blockchainState = json => {
      timestamp: json |> field("timestamp", string),
      height: json |> field("height", string),
    };
    let userCommand = json => {
      type_: json |> optional(field("usercommandtype", string)),
      fromAccount: json |> optional(field("usercommandfromaccount", string)),
      toAccount: json |> optional(field("usercommandtoaccount", string)),
      fee: json |> optional(field("usercommandfee", int)),
      amount: json |> optional(field("usercommandamount", int)),
    };

    let internalCommand = json => {
      type_: json |> optional(field("internalcommandtype", string)),
      receiverAccount:
        json |> optional(field("internalcommandrecipient", string)),
      fee: json |> optional(field("internalcommandfee", int)),
      token: json |> optional(field("internalcommandtoken", string)),
    };

    let block = json => {
      blockId: json |> field("id", int),
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

           /* Don't add unless these fields are present */
           Js.Array.some(
             (!==)(None),
             [|
               userCommand.type_,
               userCommand.toAccount,
               userCommand.fromAccount,
             |],
           )
             ? Js.Array.push(userCommand, newBlock.userCommands) |> ignore
             : ();

           /* Don't add unless these fields are present */
           Js.Array.some(
             (!==)(None),
             [|internalCommand.type_, internalCommand.receiverAccount|],
           )
             ? Js.Array.push(internalCommand, newBlock.internalCommands)
               |> ignore
             : ();

           /* Add new block to map, otherwise update with new information */
           if (Belt.Map.Int.has(map, newBlock.blockId)) {
             Belt.Map.Int.update(map, newBlock.blockId, value => {
               switch (value) {
               | Some(_) => Some(newBlock)
               | None => None
               }
             });
           } else {
             Belt.Map.Int.set(map, newBlock.blockId, newBlock);
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