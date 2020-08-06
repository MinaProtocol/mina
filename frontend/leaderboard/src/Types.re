module Block = {
  module UserCommand = {
    type userCommandType =
      | Payment
      | Delegation
      | CreateToken
      | CreateAccount
      | MintTokens
      | Unknown;

    type userCommandStatus =
      | Applied
      | Failed;

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

    let userCommandStatusOfString = s => {
      Belt.Option.mapWithDefault(s, None, status => {
        switch (status) {
        | "applied" => Some(Applied)
        | "failed" => Some(Failed)
        | _ => None
        }
      });
    };

    type t = {
      id: int,
      type_: userCommandType,
      status: option(userCommandStatus),
      fromAccount: string,
      toAccount: string,
      feePayerAccount: string,
      fee: string,
      amount: option(string),
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
            status:
              json
              |> optional(field("usercommandstatus", string))
              |> userCommandStatusOfString,
            fromAccount: json |> field("usercommandfromaccount", string),
            toAccount: json |> field("usercommandtoaccount", string),
            feePayerAccount:
              json |> field("usercommandfeepayeraccount", string),
            fee: json |> field("usercommandfee", string),
            amount: json |> optional(field("usercommandamount", string)),
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

  module BlockChainState = {
    type t = {
      timestamp: string,
      height: string,
      creatorAccount: string,
    };

    module Decode = {
      open Json.Decode;
      let blockchainState = json => {
        creatorAccount: json |> field("blockcreatoraccount", string),
        timestamp: json |> field("timestamp", string),
        height: json |> field("height", string),
      };
    };
  };

  type t = {
    id: int,
    blockchainState: BlockChainState.t,
    userCommands: array(UserCommand.t),
    internalCommands: array(InternalCommand.t),
  };

  module Decode = {
    open Json.Decode;
    let block = json => {
      id: json |> field("blockid", int),
      blockchainState: json |> BlockChainState.Decode.blockchainState,
      userCommands: [||],
      internalCommands: [||],
    };
  };

  let addCommandIfSome = (command, commands) => {
    switch (command) {
    | Some(command) => Js.Array.push(command, commands) |> ignore
    | None => ()
    };
  };

  /*
   Because UserCommands and InternalCommands have a one to many
   relationship with a block, there will be duplicate blocks ids
   with different UserCommands and InternalCommands as a result of
   the SQL query. parseBlocks() does the parsing to associate
   each UserCommand and InternalCommand to it's associated block.
    */
  let parseBlocks = blocks => {
    Belt.Map.Int.(
      blocks
      |> Array.fold_left(
           (blockMap, block) => {
             let newBlock = Decode.block(block);
             let userCommand = UserCommand.Decode.userCommand(block);
             let internalCommand =
               InternalCommand.Decode.internalCommand(block);

             if (has(blockMap, newBlock.id)) {
               update(blockMap, newBlock.id, block => {
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
               set(blockMap, newBlock.id, newBlock);
             };
           },
           empty,
         )
      |> valuesToArray
    );
  };
};

module Metrics = {
  type metricToCompute =
    | BlocksCreated
    | TransactionsSent
    | SnarkFeesCollected
    | HighestSnarkFeeCollected
    | TransactionsReceivedByEcho
    | CoinbaseReceiver;

  type t = {
    blocksCreated: option(int),
    transactionSent: option(int),
    snarkFeesCollected: option(int64),
    highestSnarkFeeCollected: option(int64),
    transactionsReceivedByEcho: option(int),
    coinbaseReceiver: option(bool),
  };
};
