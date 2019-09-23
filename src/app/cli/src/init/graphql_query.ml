open Core
open Graphql_client_lib

let query query_obj port = query query_obj (make_local_uri port "graphql")

module Get_wallets =
[%graphql
{|
query {
  ownedWallets {
    public_key: publicKey @bsDecoder(fn: "Decoders.public_key")
    locked
    balance {
      total @bsDecoder(fn: "Decoders.uint64")
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

module Set_snark_worker =
[%graphql
{|
mutation ($wallet: PublicKey) {
  setSnarkWorker (input : {wallet: $wallet}) {
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

module Cancel_user_command =
[%graphql
{|
mutation ($from: PublicKey, $to_: PublicKey, $fee: UInt64!, $nonce: UInt32) {
  sendPayment(input: {from: $from, to: $to_, amount: "0", fee: $fee, nonce: $nonce}) {
    payment {
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
