(* exclude from bisect_ppx to avoid type error on GraphQL modules *)
[@@@coverage exclude_file]

module Scalars = Graphql_lib.Scalars
module Encoders = Mina_graphql.Types.Input

module Get_tracked_accounts =
[%graphql
{|
query @encoders(module: "Encoders"){
  trackedAccounts {
    public_key: publicKey
    locked
    balance {
      total
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
      total
    }
  }
}
|}]

module Get_all_accounts =
[%graphql
{|
query ($public_key: PublicKey!) @encoders(module: "Encoders"){
  accounts(publicKey: $public_key) {
    tokenId
  }
}
|}]

module Create_account =
[%graphql
{|
mutation ($password: String!) @encoders(module: "Encoders"){
  createAccount(input: {password: $password}) {
    account: account { public_key : publicKey }
  }
}
|}]

module Create_hd_account =
[%graphql
{|
mutation ($hd_index: UInt32!) @encoders(module: "Encoders"){
  createHDAccount(input: {index: $hd_index}) {
    account : account { public_key: publicKey }
  }
}
|}]

module Unlock_account =
[%graphql
{|
mutation ($password: String!, $public_key: PublicKey!) @encoders(module: "Encoders"){
  unlockAccount(input: {password: $password, publicKey: $public_key }) {
    account: account { public_key: publicKey }
  }
}
|}]

module Lock_account =
[%graphql
{|
mutation ($public_key: PublicKey!) @encoders(module: "Encoders"){
  lockAccount(input: {publicKey: $public_key }) {
    public_key: publicKey
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
  fee
  prover
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
      source_first_pass_ledger_hash: sourceFirstPassLedgerHash
      target_first_pass_ledger_hash: targetFirstPassLedgerHash
      source_second_pass_ledger_hash: sourceSecondPassLedgerHash
      target_second_pass_ledger_hash: targetSecondPassLedgerHash
      fee_excess: feeExcess {
        feeTokenLeft
        feeExcessLeft {
          sign
          feeMagnitude
        }
        feeTokenRight
        feeExcessRight {
          sign
          feeMagnitude
        }
      }
      supply_increase : supplyIncrease
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
    lastCoinbaseReceiver
    currentCoinbaseReceiver
    }
  }
|}]

module Set_snark_worker =
[%graphql
{|
mutation ($public_key: PublicKey) @encoders(module: "Encoders"){
  setSnarkWorker (input : {publicKey: $public_key}) {
      lastSnarkWorker
    }
  }
|}]

module Set_snark_work_fee =
[%graphql
{|
mutation ($fee: UInt64!) @encoders(module: "Encoders"){
  setSnarkWorkFee(input: {fee: $fee}) {
    lastFee
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
    kind
    nonce
    feePayer { public_key: publicKey }
    receiver { public_key: publicKey }
    amount
    fee
    memo
  }
}
|}]

module Pooled_zkapp_commands = Generated_graphql_queries.Pooled_zkapp_commands

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
    public_key: publicKey
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
