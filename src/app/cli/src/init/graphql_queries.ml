(* exclude from bisect_ppx to avoid type error on GraphQL modules *)
[@@@coverage exclude_file]

module Serializing = Graphql_lib.Serializing
module Encoders = Mina_graphql.Types.Input

module Get_tracked_accounts =
[%graphql
{|
query @encoders(module: "Encoders"){
  trackedAccounts {
    public_key: publicKey @ppxCustom(module: "Serializing.Public_key")
    locked
    balance {
      total @ppxCustom(module: "Serializing.Balance")
    }
  }
}
|}]

module Get_tracked_account =
[%graphql
{|
query ($public_key: PublicKey!, $token: TokenId) @encoders(module: "Encoders"){
  account(publicKey: $public_key, token: $token) {
    balance {
      total @ppxCustom(module: "Serializing.Balance")
    }
  }
}
|}]

module Get_all_accounts =
[%graphql
{|
query ($public_key: PublicKey!) @encoders(module: "Encoders"){
  accounts(publicKey: $public_key) {
    token @ppxCustom(module: "Serializing.Token")
  }
}
|}]

module Create_account =
[%graphql
{|
mutation ($password: String!) @encoders(module: "Encoders"){
  createAccount(input: {password: $password}) {
    public_key: publicKey @ppxCustom(module: "Serializing.Public_key")
  }
}
|}]

module Create_hd_account =
[%graphql
{|
mutation ($hd_index: UInt32!) @encoders(module: "Encoders"){
  createHDAccount(input: {index: $hd_index}) {
    public_key: publicKey @ppxCustom(module: "Serializing.Public_key")
  }
}
|}]

module Unlock_account =
[%graphql
{|
mutation ($password: String!, $public_key: PublicKey!) @encoders(module: "Encoders"){
  unlockAccount(input: {password: $password, publicKey: $public_key }) {
    public_key: publicKey @ppxCustom(module: "Serializing.Public_key")
  }
}
|}]

module Lock_account =
[%graphql
{|
mutation ($public_key: PublicKey!) @encoders(module: "Encoders"){
  lockAccount(input: {publicKey: $public_key }) {
    public_key: publicKey @ppxCustom(module: "Serializing.Public_key")
  }
}
|}]

module Reload_accounts =
[%graphql
{|
mutation { reloadAccounts { success } }
|}]

module Snark_pool =
[%graphql
{|
query snarkPool {
  snarkPool {
  fee @ppxCustom(module: "Serializing.UInt64")
  prover @ppxCustom(module: "Serializing.Public_key")
  work_ids: workIds
}
}
|}]

module Pending_snark_work =
[%graphql
{|
query pendingSnarkWork {
  pendingSnarkWork {
    workBundle {
      source_ledger_hash: sourceLedgerHash
      target_ledger_hash: targetLedgerHash
      fee_excess: feeExcess {
        sign
        fee_magnitude: feeMagnitude @ppxCustom(module: "Serializing.UInt64")
      }
      supply_increase: supplyIncrease @ppxCustom(module: "Serializing.UInt64")
      work_id: workId
      }
    }
  }
|}]

module Set_coinbase_receiver =
[%graphql
{|
mutation ($public_key: PublicKey) @encoders(module: "Encoders"){
  setCoinbaseReceiver(input : {publicKey: $public_key}) {
    lastCoinbaseReceiver @ppxCustom(module: "Serializing.Public_key")
    currentCoinbaseReceiver @ppxCustom(module: "Serializing.Public_key")
    }
  }
|}]

module Set_snark_worker =
[%graphql
{|
mutation ($public_key: PublicKey) @encoders(module: "Encoders"){
  setSnarkWorker (input : {publicKey: $public_key}) {
      lastSnarkWorker @ppxCustom(module: "Serializing.Public_key")
    }
  }
|}]

module Set_snark_work_fee =
[%graphql
{|
mutation ($fee: UInt64!) @encoders(module: "Encoders"){
  setSnarkWorkFee(input: {fee: $fee}) {
    lastFee @ppxCustom(module: "Serializing.UInt64")
    }
}
|}]

module Send_payment =
[%graphql
{|
mutation ($input: SendPaymentInput!) @encoders(module: "Encoders"){
  sendPayment(input: $input){
    payment {
      id
    }
  }
}
|}]

module Send_delegation =
[%graphql
{|
mutation ($sender: PublicKey!,
          $receiver: PublicKey!,
          $fee: UInt64!,
          $nonce: UInt32,
          $memo: String) @encoders(module: "Encoders"){
  sendDelegation(input:
    {from: $sender, to: $receiver, fee: $fee, nonce: $nonce, memo: $memo}) {
    delegation {
      id
    }
  }
}
|}]

module Send_create_token =
[%graphql
{|
mutation ($sender: PublicKey,
          $receiver: PublicKey!,
          $fee: UInt64!,
          $nonce: UInt32,
          $memo: String) @encoders(module: "Encoders"){
  createToken(input:
    {feePayer: $sender, tokenOwner: $receiver, fee: $fee, nonce: $nonce, memo: $memo}) {
    createNewToken {
      id
    }
  }
}
|}]

module Send_create_token_account =
[%graphql
{|
mutation ($sender: PublicKey,
          $tokenOwner: PublicKey!,
          $receiver: PublicKey!,
          $token: TokenId!,
          $fee: UInt64!,
          $nonce: UInt32,
          $memo: String) @encoders(module: "Encoders"){
  createTokenAccount(input:
    {feePayer: $sender, tokenOwner: $tokenOwner, receiver: $receiver, token: $token, fee: $fee, nonce: $nonce, memo: $memo}) {
    createNewTokenAccount {
      id
    }
  }
}
|}]

module Send_mint_tokens =
[%graphql
{|
mutation ($sender: PublicKey!,
          $receiver: PublicKey,
          $token: TokenId!,
          $amount: UInt64!,
          $fee: UInt64!,
          $nonce: UInt32,
          $memo: String) @encoders(module: "Encoders"){
  mintTokens(input:
    {tokenOwner: $sender, receiver: $receiver, token: $token, amount: $amount, fee: $fee, nonce: $nonce, memo: $memo}) {
    mintTokens {
      id
    }
  }
}
|}]

module Export_logs =
[%graphql
{|
mutation ($basename: String) @encoders(module: "Encoders"){
  exportLogs(basename: $basename) {
    exportLogs {
      tarfile
    }
  }
}
|}]

module Get_token_owner =
[%graphql
{|
query tokenOwner($token: TokenId!) @encoders(module: "Encoders"){
  tokenOwner(token: $token)
}
|}]

module Get_inferred_nonce =
[%graphql
{|
query nonce($public_key: PublicKey!) @encoders(module: "Encoders"){
  account(publicKey: $public_key) {
    inferredNonce
  }
}
|}]

module Pooled_user_commands =
[%graphql
{|
query user_commands($public_key: PublicKey) @encoders(module: "Encoders"){
  pooledUserCommands(publicKey: $public_key) @bsRecord {
    id
    isDelegation
    nonce
    from @ppxCustom(module: "Serializing.Public_key")
    to_: to @ppxCustom(module: "Serializing.Public_key")
    amount @ppxCustom(module: "Serializing.Amount")
    fee @ppxCustom(module: "Serializing.Fee")
    memo @ppxCustom(module: "Serializing.Memo")
  }
}
|}]

module Next_available_token =
[%graphql
{|
query next_available_token {
  nextAvailableToken @ppxCustom(module: "Serializing.Token")
}
|}]

module Time_offset = [%graphql {|
query time_offset {
  timeOffset
}
|}]

module Get_peers =
[%graphql
{|
query get_peers {
  getPeers {
    host
    libp2pPort
    peerId
  }
}
|}]

module Add_peers =
[%graphql
{|
mutation ($peers: [NetworkPeer!]!, $seed: Boolean) @encoders(module: "Encoders"){
  addPeers(peers: $peers, seed: $seed) {
    host
    libp2pPort
    peerId
  }
}
|}]

module Archive_precomputed_block =
[%graphql
{|
mutation ($block: PrecomputedBlock!) @encoders(module: "Encoders"){
  archivePrecomputedBlock(block: $block) {
      applied
  }
}
|}]

module Archive_extensional_block =
[%graphql
{|
mutation ($block: ExtensionalBlock!) @encoders(module: "Encoders"){
  archiveExtensionalBlock(block: $block) {
      applied
  }
}
|}]

module Send_rosetta_transaction =
[%graphql
{|
mutation ($transaction: RosettaTransaction!) @encoders(module: "Encoders"){
  sendRosettaTransaction(input: $transaction) {
    userCommand {
      id
    }
  }
}
|}]

module Import_account =
[%graphql
{|
mutation ($path: String!, $password: String!) @encoders(module: "Encoders"){
  importAccount (path: $path, password: $password) {
    public_key: publicKey @ppxCustom(module: "Serializing.Public_key")
    already_imported: alreadyImported
    success
  }
}
|}]

module Runtime_config = [%graphql {|
query {
  runtimeConfig
}
|}]

module Thread_graph = [%graphql {|
query {
  threadGraph
}
|}]
