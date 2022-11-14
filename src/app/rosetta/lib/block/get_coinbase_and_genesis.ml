include
  [%graphql
  {|
  query {
    genesisBlock {
      creatorAccount {
        publicKey @ppxCustom(module: "Scalars.String_json")
      }
      winnerAccount {
        publicKey @ppxCustom(module: "Scalars.String_json")
      }
      protocolState {
        blockchainState {
          date @ppxCustom(module: "Scalars.String_json")
        }
        consensusState {
          blockHeight
        }
      }
      stateHash @ppxCustom(module: "Scalars.String_json")
    }
    daemonStatus {
      chainId
    }
    initialPeers
  }
|}]
