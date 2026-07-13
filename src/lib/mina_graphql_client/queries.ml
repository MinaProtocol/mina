(* exclude from bisect_ppx to avoid type error on GraphQL modules *)
[@@@coverage exclude_file]

module Client = Graphql_lib.Client

(* graphql_ppx uses Stdlib symbols instead of Base *)
open Stdlib
module Encoders = Mina_graphql.Types.Input
module Scalars = Graphql_lib.Scalars

module Unlock_account =
[%graphql
({|
  mutation ($password: String!, $public_key: PublicKey!) @encoders(module: "Encoders"){
    unlockAccount(input: {password: $password, publicKey: $public_key }) {
      account {
        public_key: publicKey
      }
    }
  }
|}
[@encoders Encoders] )]

module Send_test_payments =
[%graphql
{|
  mutation ($senders: [PrivateKey!]!,
  $receiver: PublicKey!,
  $amount: UInt64!,
  $fee: UInt64!,
  $repeat_count: UInt32!,
  $repeat_delay_ms: UInt32!) @encoders(module: "Encoders"){
    sendTestPayments(
      senders: $senders, receiver: $receiver, amount: $amount, fee: $fee,
      repeat_count: $repeat_count,
      repeat_delay_ms: $repeat_delay_ms)
  }
|}]

module Send_payment =
[%graphql
{|
 mutation ($input: SendPaymentInput!)@encoders(module: "Encoders"){
    sendPayment(input: $input){
        payment {
          id
          nonce
          hash
        }
      }
  }
|}]

module Send_payment_with_raw_sig =
[%graphql
{|
 mutation (
 $input:SendPaymentInput!,
 $rawSignature: String!
 )@encoders(module: "Encoders")
  {
    sendPayment(
      input:$input,
      signature: {rawSignature: $rawSignature}
    )
    {
      payment {
        id
        nonce
        hash
      }
    }
  }
|}]

module Send_delegation =
[%graphql
{|
  mutation ($input: SendDelegationInput!) @encoders(module: "Encoders"){
    sendDelegation(input:$input){
        delegation {
          id
          nonce
          hash
        }
      }
  }
|}]

module Send_delegation_with_raw_sig =
[%graphql
{|
 mutation (
 $input:SendDelegationInput!,
 $rawSignature: String!
 )@encoders(module: "Encoders")
  {
    sendDelegation(
      input:$input,
      signature: {rawSignature: $rawSignature}
    )
    {
      delegation {
        id
        nonce
        hash
      }
    }
  }
|}]

module Set_snark_worker =
[%graphql
{|
  mutation ($input: SetSnarkWorkerInput! ) @encoders(module: "Encoders"){
    setSnarkWorker(input:$input){
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

module Get_account_data =
[%graphql
{|
  query ($public_key: PublicKey!) @encoders(module: "Encoders"){
    account(publicKey: $public_key) {
      nonce
      delegateAccount {
        publicKey
      }
      balance {
        total @ppxCustom(module: "Scalars.Balance")
      }
    }
  }
|}]

(* TODO: temporary version *)
module Send_test_zkapp = Generated_graphql_queries.Send_test_zkapp
module Pooled_zkapp_commands = Generated_graphql_queries.Pooled_zkapp_commands

module Query_peer_id =
[%graphql
{|
  query {
    daemonStatus {
      addrsAndPorts {
        peer {
          peerId
        }
      }
      peers {  peerId }

    }
  }
|}]

module Global_slot_since_hard_fork =
[%graphql
{|
  query {
    daemonStatus {
      consensusTimeNow {
        globalSlot @ppxCustom(module: "Scalars.GlobalSlotSinceHardFork")
      }
    }
  }
|}]

module Best_chain =
(* "slot" is serialized using Graphql_lib.Scalars.Slot
   to use that, we'd need to add the 'consensus' library,
   which seems an undesirable dependency

   semantically, it's a slot since hard fork, so decode it as such

   that benign mismatch could be avoided by changing the encoding type
   in proof_of_stake.ml
*)
[%graphql
{|
  query ($max_length: Int) @encoders(module: "Encoders"){
    bestChain (maxLength: $max_length) {
      stateHash @ppxCustom(module: "Graphql_lib.Scalars.String_json")
      commandTransactionCount
      creatorAccount {
        publicKey @ppxCustom(module: "Graphql_lib.Scalars.JSON")
      }
      protocolState {
        consensusState {
          blockHeight
          slotSinceGenesis @ppxCustom(module: "Scalars.GlobalSlotSinceGenesis")
          slot @ppxCustom(module: "Scalars.GlobalSlotSinceHardFork")
        }
      }
    }
  }
|}]

module Query_metrics =
[%graphql
{|
  query {
    daemonStatus {
      metrics {
        blockProductionDelay
        transactionPoolDiffReceived
        transactionPoolDiffBroadcasted
        transactionsAddedToPool
        transactionPoolSize
      }
    }
  }
|}]

module Query_sync_status = [%graphql {|
  query {
    syncStatus
  }
|}]

module Query_network_id = [%graphql {|
  query {
    networkID
  }
|}]

module Genesis_ledger_export = [%graphql {|
  query {
    fork_config
  }
|}]

module StartFilteredLog =
[%graphql
{|
  mutation ($filter: [String!]!) @encoders(module: "Encoders"){
    startFilteredLog(filter: $filter)
  }
|}]

module GetFilteredLogEntries =
[%graphql
{|
  query ($offset: Int!) @encoders(module: "Encoders"){
    getFilteredLogEntries(offset: $offset) {
        logMessages,
        isCapturing,
    }
  }
|}]

module Account =
[%graphql
{|
  query ($public_key: PublicKey!, $token: UInt64) {
    account (publicKey : $public_key, token : $token) {
      balance { liquid
                locked
                total
              }
      delegate
      nonce
      inferredNonce
      permissions { editActionState
                    editState
                    incrementNonce
                    receive
                    send
                    access
                    setDelegate
                    setPermissions
                    setZkappUri
                    setTokenSymbol
                    setVerificationKey { auth
                                         txnVersion
                                       }
                    setVotingFor
                    setTiming
                  }
      actionState
      zkappState
      zkappUri
      timing { cliffTime @ppxCustom(module: "Graphql_lib.Scalars.JSON")
               cliffAmount
               vestingPeriod @ppxCustom(module: "Graphql_lib.Scalars.JSON")
               vestingIncrement
               initialMinimumBalance
             }
      tokenId
      tokenSymbol
      verificationKey { verificationKey
                        hash
                      }
      votingFor
    }
  }
|}]

module Sync_status = [%graphql {|
  query {
    syncStatus
  }
|}]

module Daemon_status =
[%graphql
{|
  query {
    daemonStatus {
      syncStatus
      blockchainLength
      highestBlockLengthReceived
      uptimeSecs
      stateHash
      commitId
      peers {
        peerId
        host
        libp2pPort
      }
    }
  }
|}]

module Daemon_readiness =
[%graphql
{|
  query {
    daemonStatus {
      syncStatus
      blockchainLength
      highestBlockLengthReceived
      peers {
        peerId
      }
    }
  }
|}]

module Best_chain_for_slot_end_test =
[%graphql
{|
    query ($max_length: Int) @encoders(module: "Encoders") {
      bestChain(maxLength: $max_length) {
        stateHash @ppxCustom(module: "Graphql_lib.Scalars.String_json")
        commandTransactionCount
        protocolState {
          consensusState {
            slot @ppxCustom(module: "Scalars.GlobalSlotSinceHardFork")
            slotSinceGenesis @ppxCustom(module: "Scalars.GlobalSlotSinceGenesis")
          }
        }
        transactions {
          coinbase
        }
        snarkJobs {
          workIds
        }
      }
    }
  |}]
