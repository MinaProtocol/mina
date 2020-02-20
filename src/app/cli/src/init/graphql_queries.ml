module Decoders = Graphql_client.Decoders

module Get_wallets =
[%graphql
{|
query {
  ownedWallets {
    public_key: publicKey @bsDecoder(fn: "Decoders.public_key")
    locked
    balance {
      total @bsDecoder(fn: "Decoders.balance")
    }
  }
}
|}]

module Get_wallet =
[%graphql
{|
query ($public_key: PublicKey) {
  wallet(publicKey: $public_key) {
    public_key: publicKey @bsDecoder(fn: "Decoders.public_key")
    balance {
      total @bsDecoder(fn: "Decoders.balance")
    }
  }
}
|}]

module Add_wallet =
[%graphql
{|
mutation ($password: String) {
  addWallet(input: {password: $password}) {
    public_key: publicKey @bsDecoder(fn: "Decoders.public_key")
  }
}
|}]

module Unlock_wallet =
[%graphql
{|
mutation ($password: String, $public_key: PublicKey) {
  unlockWallet(input: {password: $password, publicKey: $public_key }) {
    public_key: publicKey @bsDecoder(fn: "Decoders.public_key")
  }
}
|}]

module Lock_wallet =
[%graphql
{|
mutation ($public_key: PublicKey) {
  lockWallet(input: {publicKey: $public_key }) {
    public_key: publicKey @bsDecoder(fn: "Decoders.public_key")
  }
}
|}]

module Reload_wallets = [%graphql {|
mutation { reloadWallets { success } }
|}]

module Snark_pool =
[%graphql
{|
query snarkPool {
  snarkPool {
  fee @bsDecoder(fn: "Decoders.uint64")
  prover @bsDecoder(fn: "Decoders.public_key")
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
        fee_magnitude: feeMagnitude @bsDecoder(fn: "Decoders.uint64")
      }
      supply_increase: supplyIncrease @bsDecoder(fn: "Decoders.uint64")
      work_id: workId
      }
    }
    }
|}]

module Set_staking =
[%graphql
{|
mutation ($public_key: PublicKey) {
  setStaking(input : {publicKeys: [$public_key]}) {
    lastStaking
    }
  }
|}]

module Set_snark_worker =
[%graphql
{|
mutation ($wallet: PublicKey) {
  setSnarkWorker (input : {publicKey: $wallet}) {
      lastSnarkWorker @bsDecoder(fn: "Decoders.optional_public_key")
    }
  }
|}]

module Set_snark_work_fee =
[%graphql
{|
mutation ($fee: UInt64!) {
  setSnarkWorkFee(input: {fee: $fee}) {
    lastFee @bsDecoder(fn: "Decoders.uint64")
    }
}
|}]

module Send_payment =
[%graphql
{|
mutation ($sender: PublicKey!,
          $receiver: PublicKey!,
          $amount: UInt64!,
          $fee: UInt64!,
          $nonce: UInt32,
          $memo: String) {
  sendPayment(input: 
    {from: $sender, to: $receiver, amount: $amount, fee: $fee, nonce: $nonce, memo: $memo}) {
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
          $memo: String) {
  sendDelegation(input: 
    {from: $sender, to: $receiver, fee: $fee, nonce: $nonce, memo: $memo}) {
    delegation {
      id
    }
  }
}
|}]

module Get_inferred_nonce =
[%graphql
{|
query nonce($public_key: PublicKey) {
  wallet(publicKey: $public_key) {
    inferredNonce
  }
}
|}]

module Pooled_user_commands = struct
  open Graphql_client.User_command

  include [%graphql
  {|
query user_commands($public_key: PublicKey) {
  pooledUserCommands(publicKey: $public_key) @bsRecord {
    id
    isDelegation
    nonce
    from @bsDecoder(fn: "Decoders.public_key")
    to_: to @bsDecoder(fn: "Decoders.public_key")
    amount @bsDecoder(fn: "Decoders.amount")
    fee @bsDecoder(fn: "Decoders.fee")
    memo @bsDecoder(fn: "Coda_base.User_command_memo.of_string")
  }
}
|}]
end
