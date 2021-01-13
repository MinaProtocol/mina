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
      hash: string,
      nonce: string,
      type_: userCommandType,
      status: option(userCommandStatus),
      fromAccount: string,
      toAccount: string,
    };

    module Decode = {
      open Json.Decode;
      let userCommand = json =>
        switch (json |> field("usercommandid", int)) {
        | id =>
          {
            id,
            hash: json |> field("usercommandhash", string),
            nonce: json |> field("usercommandnonce", string),
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
      hash: string,
      type_: internalCommandType,
      receiverAccount: string,
      fee: string,
    };

    module Decode = {
      open Json.Decode;
      let internalCommand = json =>
        switch (json |> field("internalcommandid", int)) {
        | id =>
          {
            id,
            hash: json |> field("internalcommandhash", string),
            type_:
              json
              |> field("internalcommandtype", string)
              |> internalCommandTypeOfString,
            receiverAccount:
              json |> field("internalcommandrecipient", string),
            fee: json |> field("internalcommandfee", string),
          }
          ->Some
        | exception (DecodeError(_)) => None
        };
    };
  };

  type command =
    | UserCommand(UserCommand.t)
    | InternalCommand(InternalCommand.t);

  module BlockChainState = {
    type t = {
      timestamp: string,
      creatorAccount: string,
      coinbaseReceiver: option(string),
    };

    module Decode = {
      open Json.Decode;
      let blockchainState = json => {
        {
          creatorAccount: json |> field("blockcreatoraccount", string),
          coinbaseReceiver: None,
          timestamp: json |> field("timestamp", string),
        };
      };
    };
  };

  type t = {
    stateHash: string,
    blockchainState: BlockChainState.t,
    userCommands: array(UserCommand.t),
    internalCommands: array(InternalCommand.t),
  };

  module Decode = {
    open Json.Decode;
    let block = json => {
      stateHash: json |> field("state_hash", string),
      blockchainState: json |> BlockChainState.Decode.blockchainState,
      userCommands: [||],
      internalCommands: [||],
    };
  };

  let addCoinbaseReceiverIfSome = (block, coinbaseReceiver) => {
    switch (coinbaseReceiver) {
    | Some(_) =>
      let updatedBlockchainState = {
        ...block.blockchainState,
        coinbaseReceiver,
      };
      {...block, blockchainState: updatedBlockchainState};
    | None => block
    };
  };

  let addCommandIfValid = (command, block) => {
    switch (command) {
    | UserCommand(newCommand) =>
      block.userCommands
      ->Belt.Array.keep(command => {newCommand.hash === command.hash})
      ->Belt.Array.length
      === 0
        ? Js.Array.push(newCommand, block.userCommands) |> ignore : ()

    | InternalCommand(newCommand) =>
      block.internalCommands
      ->Belt.Array.keep(command => {newCommand.hash === command.hash})
      ->Belt.Array.length
      === 0
        ? Js.Array.push(newCommand, block.internalCommands) |> ignore : ()
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
    Belt.Map.String.(
      blocks
      |> Array.fold_left(
           (blockMap, block) => {
             let newBlock = Decode.block(block);
             let userCommand = UserCommand.Decode.userCommand(block);
             let internalCommand =
               InternalCommand.Decode.internalCommand(block);

             let coinbaseReceiver =
               switch (internalCommand) {
               | Some(internalCommand) =>
                 switch (internalCommand.type_) {
                 | Coinbase => Some(internalCommand.receiverAccount)
                 | _ => None
                 }
               | _ => None
               };

             if (has(blockMap, newBlock.stateHash)) {
               update(blockMap, newBlock.stateHash, block => {
                 switch (block) {
                 | Some(currentBlock) =>
                   Belt.Option.forEach(userCommand, newCommand => {
                     addCommandIfValid(UserCommand(newCommand), currentBlock)
                   });

                   Belt.Option.forEach(internalCommand, newCommand => {
                     addCommandIfValid(
                       InternalCommand(newCommand),
                       currentBlock,
                     )
                   });

                   let block =
                     addCoinbaseReceiverIfSome(
                       currentBlock,
                       coinbaseReceiver,
                     );
                   Some(block);
                 | None => None
                 }
               });
             } else {
               Belt.Option.forEach(userCommand, newCommand => {
                 addCommandIfValid(UserCommand(newCommand), newBlock)
               });

               Belt.Option.forEach(internalCommand, newCommand => {
                 addCommandIfValid(InternalCommand(newCommand), newBlock)
               });
               let block =
                 addCoinbaseReceiverIfSome(newBlock, coinbaseReceiver);

               set(blockMap, block.stateHash, block);
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
    | CoinbaseReceiver
    | CreateAndSendToken
    | ReceiveToken;

  type t = {
    blocksCreated: option(int),
    transactionSent: option(int),
    snarkFeesCollected: option(int64),
    highestSnarkFeeCollected: option(int64),
    transactionsReceivedByEcho: option(int),
    coinbaseReceiver: option(bool),
  };
};
