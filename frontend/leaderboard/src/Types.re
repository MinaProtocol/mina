module Block = {
  module UserCommand = {
    type userCommandType =
      | Payment
      | Delegation
      | CreateToken
      | CreateAccount
      | MintTokens
      | Unknown;

    /* These strings match the types returned from the archive DB */
    let userCommandTypeOfString = s => {
      switch (s) {
      | "payment" => Payment
      | "delegation" => Delegation
      | "create_token" => CreateToken
      | "create_account" => CreateAccount
      | "mint_tokens" => MintTokens
      | _ => Unknown
      };
    };

    type t = {
      id: int,
      type_: userCommandType,
      fromAccount: string,
      toAccount: string,
      fee: string,
      amount: string,
    };

    module Decode = {
      open Json.Decode;
      let userCommand = json =>
        switch (json |> field("usercommandid", int)) {
        | id =>
          {
            id,
            type_:
              json
              |> field("usercommandtype", string)
              |> userCommandTypeOfString,
            fromAccount: json |> field("usercommandfromaccount", string),
            toAccount: json |> field("usercommandtoaccount", string),
            fee: json |> field("usercommandfee", string),
            amount: json |> field("usercommandamount", string),
          }
          ->Some
        | exception (DecodeError(_)) => None
        };
    };
  };

  module InternalCommand = {
    type internalCommandType =
      | FeeTransfer
      | Coinbase
      | Unknown;

    /* These strings match the types returned from the archive DB */
    let internalCommandTypeOfString = s => {
      switch (s) {
      | "fee_transfer" => FeeTransfer
      | "coinbase" => Coinbase
      | _ => Unknown
      };
    };

    type t = {
      id: int,
      type_: internalCommandType,
      receiverAccount: string,
      fee: string,
      token: string,
    };

    module Decode = {
      open Json.Decode;
      let internalCommand = json =>
        switch (json |> field("internalcommandid", int)) {
        | id =>
          {
            id,
            type_:
              json
              |> field("internalcommandtype", string)
              |> internalCommandTypeOfString,
            receiverAccount:
              json |> field("internalcommandrecipient", string),
            fee: json |> field("internalcommandfee", string),
            token: json |> field("internalcommandtoken", string),
          }
          ->Some
        | exception (DecodeError(_)) => None
        };
    };
  };

  type blockchainState = {
    timestamp: string,
    height: string,
  };

  type t = {
    id: int,
    blockchainState,
    creatorAccount: string,
    userCommands: array(UserCommand.t),
    internalCommands: array(InternalCommand.t),
  };

  let addCommandIfSome = (command, commands) => {
    switch (command) {
    | Some(command) => Js.Array.push(command, commands) |> ignore
    | None => ()
    };
  };

  module Decode = {
    open Json.Decode;

    let blockchainState = json => {
      timestamp: json |> field("timestamp", string),
      height: json |> field("height", string),
    };

    let block = json => {
      id: json |> field("blockid", int),
      creatorAccount: json |> field("blockcreatoraccount", string),
      blockchainState: json |> blockchainState,
      userCommands: [||],
      internalCommands: [||],
    };
  };

  let parseBlocks = blocks => {
    Belt.Map.Int.(
      blocks
      |> Array.fold_left(
           (map, block) => {
             let newBlock = Decode.block(block);
             let userCommand = UserCommand.Decode.userCommand(block);
             let internalCommand =
               InternalCommand.Decode.internalCommand(block);

             if (has(map, newBlock.id)) {
               update(map, newBlock.id, block => {
                 switch (block) {
                 | Some(currentBlock) =>
                   addCommandIfSome(userCommand, currentBlock.userCommands);
                   addCommandIfSome(
                     internalCommand,
                     currentBlock.internalCommands,
                   );
                   Some(currentBlock);
                 | None => None
                 }
               });
             } else {
               addCommandIfSome(userCommand, newBlock.userCommands);
               addCommandIfSome(internalCommand, newBlock.internalCommands);
               set(map, newBlock.id, newBlock);
             };
           },
           empty,
         )
      |> valuesToArray
    );
  };
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
    //snarkWorkCreated: option(int),
    snarkFeesCollected: option(int64),
    highestSnarkFeeCollected: option(int64),
    transactionsReceivedByEcho: option(int),
    coinbaseReceiver: option(bool),
  };
};
