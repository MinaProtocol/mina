# Snapp test transaction tool

A tool to generate snapp transactions that can be sent to a mina test network. For more information on snapps, checkout the following resources: https://docs.minaprotocol.com/en/snapps.
The WIP progress spec [here](https://o1-labs.github.io/snapps-txns-reference-impl/target/doc/snapps_txn_reference_impl/index.html) proposes the structure and behavior of mina snapp transactions.

The smart contract (which users might write using snarkyJS) used in the tool is intended only for testing as it does no operation on the state and simply accepts any update. The tool provides options to deploy this smart contract to a mina account and make various updates to the account

#### Usage

The tool generates a graphQL `sendSnapp` mutation that can be sent to the graphQL server the daemon starts by default at port 3085. One can use the UI to interact with the local graphQL server mounted at http://localhost:3085/graphql and paste the graphQL object that the tool prints

The commands proivded by this tool are-

```shell
$mina-snapp-test-transaction -help
Snapp test transaction

  mina-snapp-test-transaction SUBCOMMAND

=== subcommands ===

  create-snapp-account            Generate a snapp transaction that creates a
                                  snapp account
  upgrade-snapp                   Generate a snapp transaction that updates the
                                  verification key
  transfer-funds                  Generate a snapp transaction that makes
                                  multiple transfers from one account
  update-state                    Generate a snapp transaction that updates
                                  snapp state
  update-snapp-uri                Generate a snapp transaction that updates the
                                  snapp uri
  update-sequence-state           Generate a snapp transaction that updates
                                  snapp state
  update-token-symbol             Generate a snapp transaction that updates
                                  token symbol
  update-permissions              Generate a snapp transaction that updates the
                                  permissions of a snapp account
  test-snapp-with-genesis-ledger  Generate a trivial snapp transaction and
                                  genesis ledger with verification key for
                                  testing
  version                         print version information
  help                            explain a given subcommand (perhaps
                                  recursively)

```

### Example usage

#### 1. Create a snapp account / Deploy the test smart contract

`create-snapp-account` command takes the following input to create a snapp account and deploy the test smart contract. 

```shell
$mina-snapp-test-transaction create-snapp-account -help
Generate a snapp transaction that creates a snapp account

  mina-snapp-test-transaction create-snapp-account 

=== flags ===

  --fee-payer-key KEYFILE      Private key file for the fee payer of the
                               transaction (should already be in the ledger)
  --nonce NN                   Nonce of the fee payer account
  --receiver-amount NN         Receiver amount in Mina
  --snapp-account-key KEYFILE  Private key file to create a new snapp account
  [--debug]                    Debug mode, generates transaction snark
  [--fee FEE]                  Amount you are willing to pay to process the
                               transaction (default: 1) (minimum: 0.003)
  [--memo STRING]              Memo accompanying the transaction
  [-help]                      print this help text and exit
                               (alias: -?)
```

For example:

```shell
$mina-snapp-test-transaction create-snapp-account --fee-payer-key my-fee-payer --nonce 0 --receiver-amount 2 --snapp-account-key my-snapp-key
```

generates the following graphQL object- a snapp transaction as input to the `sendSnapp` mutation. A snapp transaction is basically a list of parties where each [party](https://o1-labs.github.io/snapps-txns-reference-impl/target/doc/snapps_txn_reference_impl/party/index.html) is an update performed on an account.

The snapp transaction here has three parties-

1. the fee payer party which specifies who pays the transaction fees and how much
2. A party that pays the account creation fee to create the new snapp snapp account which in this case is the same as the fee payer
3. A party to create a new snapp account, set its verification key associated with the test smart contract, and update `editState` and `editSequenceState` permissions to use proofs as [authorization](https://o1-labs.github.io/snapps-txns-reference-impl/target/doc/snapps_txn_reference_impl/party/enum.PartyAuthorization.html).

The authorization used in each of the parties here is a signature of the respective accounts i.e., the updates on these accounts are authorized as per the accounts' permissions.

```
mutation MyMutation {
  __typename
  sendSnapp(input: {
    feePayer:{data:{body:{publicKey:"B62qpfgnUm7zVqi8MJHNB2m37rtgMNDbFNhC2DpMmmVpQt8x6gKv9Ww",
        update:{appState:[null,
            null,
            null,
            null,
            null,
            null,
            null,
            null],
          delegate:null,
          verificationKey:null,
          permissions:null,
          snappUri:null,
          tokenSymbol:null,
          timing:null,
          votingFor:null},
        fee:"10000000000",
        events:[],
        sequenceEvents:[],
        callData:"0x0000000000000000000000000000000000000000000000000000000000000000",
        callDepth:0,
        protocolState:{snarkedLedgerHash:null,
          snarkedNextAvailableToken:null,
          timestamp:null,
          blockchainLength:null,
          minWindowDensity:null,
          lastVrfOutput:null,
          totalCurrency:null,
          globalSlotSinceHardFork:null,
          globalSlotSinceGenesis:null,
          stakingEpochData:{ledger:{hash:null,
              totalCurrency:null},
            seed:null,
            startCheckpoint:null,
            lockCheckpoint:null,
            epochLength:null},
          nextEpochData:{ledger:{hash:null,
              totalCurrency:null},
            seed:null,
            startCheckpoint:null,
            lockCheckpoint:null,
            epochLength:null}}},
      predicate:"0"},
    authorization:"7mXCpPWUUybaLKWQZC7jQc4EQNgAoS5aX5AX7TkrWw73bA2P1q616Drqk4gBeZasx1MNMP5mNUEzvXZGUFb2CHaCXTYrDGGr"},
    otherParties:[{data:{body:{publicKey:"B62qpfgnUm7zVqi8MJHNB2m37rtgMNDbFNhC2DpMmmVpQt8x6gKv9Ww",
        update:{appState:[null,
            null,
            null,
            null,
            null,
            null,
            null,
            null],
          delegate:null,
          verificationKey:null,
          permissions:null,
          snappUri:null,
          tokenSymbol:null,
          timing:null,
          votingFor:null},
        tokenId:"1",
        balanceChange:{magnitude:"2000000000",
          sign:MINUS},
        incrementNonce:true,
        events:[],
        sequenceEvents:[],
        callData:"0x0000000000000000000000000000000000000000000000000000000000000000",
        callDepth:0,
        protocolState:{snarkedLedgerHash:null,
          snarkedNextAvailableToken:null,
          timestamp:null,
          blockchainLength:null,
          minWindowDensity:null,
          lastVrfOutput:null,
          totalCurrency:null,
          globalSlotSinceHardFork:null,
          globalSlotSinceGenesis:null,
          stakingEpochData:{ledger:{hash:null,
              totalCurrency:null},
            seed:null,
            startCheckpoint:null,
            lockCheckpoint:null,
            epochLength:null},
          nextEpochData:{ledger:{hash:null,
              totalCurrency:null},
            seed:null,
            startCheckpoint:null,
            lockCheckpoint:null,
            epochLength:null}},
        useFullCommitment:false},
      predicate:{nonce:"1"}},
    authorization:{signature:"7mXLzcQEYLofdZHMbrSP3euqa1GVHESowB2f2ExtV7tosVcC4Jw32oydZa9XnfvfFo3wDHfturq6WP5tryM2jy4ZJ6jeKyn5"}},
    {data:{body:{publicKey:"B62qmQDtbNTymWXdZAcp4JHjfhmWmuqHjwc6BamUEvD8KhFpMui2K1Z",
        update:{appState:[null,
            null,
            null,
            null,
            null,
            null,
            null,
            null],
          delegate:null,
          verificationKey:{verificationKey:"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", hash:"0x18F78C4C0BE6CC4E27B232CF5B41ADAA63D881ABAA68155AA5035769C2A11C85"},
          permissions:{stake:true,
            editState:Proof,
            send:Signature,
            receive:None,
            setDelegate:Signature,
            setPermissions:Signature,
            setVerificationKey:Signature,
            setSnappUri:Signature,
            editSequenceState:Proof,
            setTokenSymbol:Signature,
            incrementNonce:Signature,
            setVotingFor:Signature},
          snappUri:null,
          tokenSymbol:null,
          timing:null,
          votingFor:null},
        tokenId:"1",
        balanceChange:{magnitude:"2000000000",
          sign:PLUS},
        incrementNonce:false,
        events:[],
        sequenceEvents:[],
        callData:"0x0000000000000000000000000000000000000000000000000000000000000000",
        callDepth:0,
        protocolState:{snarkedLedgerHash:null,
          snarkedNextAvailableToken:null,
          timestamp:null,
          blockchainLength:null,
          minWindowDensity:null,
          lastVrfOutput:null,
          totalCurrency:null,
          globalSlotSinceHardFork:null,
          globalSlotSinceGenesis:null,
          stakingEpochData:{ledger:{hash:null,
              totalCurrency:null},
            seed:null,
            startCheckpoint:null,
            lockCheckpoint:null,
            epochLength:null},
          nextEpochData:{ledger:{hash:null,
              totalCurrency:null},
            seed:null,
            startCheckpoint:null,
            lockCheckpoint:null,
            epochLength:null}},
        useFullCommitment:true},
      predicate:{account:null,
        nonce:null}},
    authorization:{signature:"7mXHY5h3g4ghS4SBMGzs1yZBNE5EjMK5q6XHXFeE1FYSJgb8vAjuT81mzrC8J3DPWQSDq3EHAKm1L2Pf7YuTHTMNjUioK7Pq"}}] })
}
```

After the transaction is sent and included in a block, a new snapp account with the verification of the test smart contract gets created. The account information can be queried through the graphQL `account` query.

```
query MyQuery {
  account(publicKey: "B62qmQDtbNTymWXdZAcp4JHjfhmWmuqHjwc6BamUEvD8KhFpMui2K1Z") {
    nonce
    balance {
      total
    }
    verificationKey {
      hash
      verificationKey
    }
    permissions {
      editSequenceState
      editState
      incrementNonce
      receive
      send
      setDelegate
      setPermissions
      setSnappUri
      setTokenSymbol
      setVerificationKey
      setVotingFor
      stake
    }
  }
}
```

Query result:

```json
{
  "data": {
    "account": {
      "balance": {
        "total": "1000000000"
      },
      "verificationKey": {
        "hash": "11292887885696531659094127423705404064892721380499236041832155935416728493189"
      },
      "permissions": {
        "editSequenceState": "Proof",
        "editState": "Proof",
        "incrementNonce": "Signature",
        "receive": "None",
        "send": "Signature",
        "setDelegate": "Signature",
        "setPermissions": "Signature",
        "setSnappUri": "Signature",
        "setTokenSymbol": "Signature",
        "setVerificationKey": "Signature",
        "setVotingFor": "Signature",
        "stake": true
      },
      "nonce": "0"
    }
  }
}
```

#### 2. Update snapp state

A snapp transaction to update the 8 field elements representing the on-chain state of a smart contract

```shell
$mina-snapp-test-transaction update-state -help
Generate a snapp transaction that updates snapp state

  mina-snapp-test-transaction update-state 

=== flags ===

  --fee-payer-key KEYFILE                         Private key file for the fee
                                                  payer of the transaction
                                                  (should already be in the
                                                  ledger)
  --nonce NN                                      Nonce of the fee payer account
  --snapp-account-key KEYFILE                     Private key file to create a
                                                  new snapp account
  [--debug]                                       Debug mode, generates
                                                  transaction snark
  [--fee FEE]                                     Amount you are willing to pay
                                                  to process the transaction
                                                  (default: 1) (minimum: 0.003)
  [--memo STRING]                                 Memo accompanying the
                                                  transaction
  [--snapp-state String(hash)|Integer(field] ...  element) a list of 8 elements
                                                  that represent the snapp state
                                                  (Use empty string for no-op)
  [-help]                                         print this help text and exit
                                                  (alias: -?)

```

For example:

```shell
$mina-snapp-test-transaction update-state --fee-payer-key my-fee-payer --nonce 2 --snapp-account-key my-snapp-key --fee 5 --snapp-state 1 --snapp-state 2 --snapp-state 3 --snapp-state 4 --snapp-state 5 --snapp-state 6 --snapp-state 7 --snapp-state 8
```

The snapp transaction here has two parties-

1. The fee payer party which specifies who pays the transaction fees and how much
2. A party that updates the `app_state` of the snapp account. The authorization required to update the state is a proof (as updated the by deploy-snapp transaction above `editState: Proof`)

```
mutation MyMutation {
  __typename
  sendSnapp(input: {
    feePayer:{data:{body:{publicKey:"B62qpfgnUm7zVqi8MJHNB2m37rtgMNDbFNhC2DpMmmVpQt8x6gKv9Ww",
        update:{appState:[null,
            null,
            null,
            null,
            null,
            null,
            null,
            null],
          delegate:null,
          verificationKey:null,
          permissions:null,
          snappUri:null,
          tokenSymbol:null,
          timing:null,
          votingFor:null},
        fee:"10000000000",
        events:[],
        sequenceEvents:[],
        callData:"0x0000000000000000000000000000000000000000000000000000000000000000",
        callDepth:0,
        protocolState:{snarkedLedgerHash:null,
          snarkedNextAvailableToken:null,
          timestamp:null,
          blockchainLength:null,
          minWindowDensity:null,
          lastVrfOutput:null,
          totalCurrency:null,
          globalSlotSinceHardFork:null,
          globalSlotSinceGenesis:null,
          stakingEpochData:{ledger:{hash:null,
              totalCurrency:null},
            seed:null,
            startCheckpoint:null,
            lockCheckpoint:null,
            epochLength:null},
          nextEpochData:{ledger:{hash:null,
              totalCurrency:null},
            seed:null,
            startCheckpoint:null,
            lockCheckpoint:null,
            epochLength:null}}},
      predicate:"2"},
    authorization:"7mXJhuKym4S8h2h5XDaTDUS6Nd5kFtj23tnBvn8J8X2ukyUNjv9Pr8fidh3UWv89DaLfj19y4Aix1Z5JjxramGcsyjRVULbU"},
    otherParties:[{data:{body:{publicKey:"B62qmQDtbNTymWXdZAcp4JHjfhmWmuqHjwc6BamUEvD8KhFpMui2K1Z",
        update:{appState:["0x0000000000000000000000000000000000000000000000000000000000000001",
            "0x0000000000000000000000000000000000000000000000000000000000000002",
            "0x0000000000000000000000000000000000000000000000000000000000000003",
            "0x0000000000000000000000000000000000000000000000000000000000000004",
            "0x0000000000000000000000000000000000000000000000000000000000000005",
            "0x0000000000000000000000000000000000000000000000000000000000000006",
            "0x0000000000000000000000000000000000000000000000000000000000000007",
            "0x0000000000000000000000000000000000000000000000000000000000000008"],
          delegate:null,
          verificationKey:null,
          permissions:null,
          snappUri:null,
          tokenSymbol:null,
          timing:null,
          votingFor:null},
        tokenId:"1",
        balanceChange:{magnitude:"0",
          sign:PLUS},
        incrementNonce:false,
        events:[],
        sequenceEvents:[],
        callData:"0x0000000000000000000000000000000000000000000000000000000000000000",
        callDepth:0,
        protocolState:{snarkedLedgerHash:null,
          snarkedNextAvailableToken:null,
          timestamp:null,
          blockchainLength:null,
          minWindowDensity:null,
          lastVrfOutput:null,
          totalCurrency:null,
          globalSlotSinceHardFork:null,
          globalSlotSinceGenesis:null,
          stakingEpochData:{ledger:{hash:null,
              totalCurrency:null},
            seed:null,
            startCheckpoint:null,
            lockCheckpoint:null,
            epochLength:null},
          nextEpochData:{ledger:{hash:null,
              totalCurrency:null},
            seed:null,
            startCheckpoint:null,
            lockCheckpoint:null,
            epochLength:null}},
        useFullCommitment:true},
      predicate:{account:null,
        nonce:null}},
    authorization:{proof:"KChzdGF0ZW1lbnQoKHByb29mX3N0YXRlKChkZWZlcnJlZF92YWx1ZXMoKHBsb25rKChhbHBoYSgoaW5uZXIoNTk1NGM0NmNiNWUxYzJhMSA4YWJmNWQyMGE2MDlkNzYzKSkpKShiZXRhKDA5MmEyNjYwNzJmYjZjNjYgODYyMTVlODkwMWRjY2NlMCkpKGdhbW1hKGIzNGViY2I4NzZjNWY4MGUgMjZjZjZmNjlhZTAyNDY0YykpKHpldGEoKGlubmVyKDhjMGU4ODllNjY4ODJiNjUgZjliZTA0MGNmNzFkNTE0YikpKSkpKShjb21iaW5lZF9pbm5lcl9wcm9kdWN0KFNoaWZ0ZWRfdmFsdWUgMHgwRkRFNDE0QzgxODk3ODFBMjI0OENCODM4MjFBQkVGN0VCM0Q5M0VFQ0NFNkVBODVENDI2NEQzQTU1NTNERTZDKSkoYihTaGlmdGVkX3ZhbHVlIDB4M0IwMjE5NDExMkQ2RDRBQ0VBMTYyNzA4OTMxQjRBMzU5OEIzNEI1MEIwOUQwQzEyOTI4OUE0OEQ1QjlDQkI2MikpKHhpKChpbm5lcig4ZmU0N2IyMmVjMGY3NzE3IDdlZjQ4YjVhZTlhYTViYTEpKSkpKGJ1bGxldHByb29mX2NoYWxsZW5nZXMoKChwcmVjaGFsbGVuZ2UoKGlubmVyKGQ3ODU5ZWM2NmM4ODZkNzYgODMxMDliYjk0YjQ1ZDBiZikpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGQ1ZGUyMzc2MDBlZmQzNTQgODI2YzkxZWNhOGEwOGZkMCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDUxMzY4MzUxNzBhZDU1M2MgZWJiZTMyNjNlY2U5NDlhMykpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDA5N2RiYjAwYzNiNTc0NDQgZTEyZjg0ZDNlOTBlM2YxYSkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDgyYTc3YjM5ZDNjNjQxYjAgZDMyZmJhYjM0NzUyYTJiZCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDFkZGFjOTYwNzgwYTIyOTIgM2MwNzQzMWJlMjY5NWQ1NykpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDllYWQ0NTdkMzNmMWFkOTggMmZmMzU3NWI5ZGI2NzM3ZikpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDkzOWFlZTg5NGU1MTI0MzcgNzMyMGNjZGQ5MmQ5NGM3NykpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDIyZGMzMWUyYzQyOWZkNTQgMGZmZGZlNTFiMDg0YTY4MCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGRlNzY1NTE5ZWU1ZTBjMTUgNTJjOWE2NTgwYjU1MzZlYykpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGYzMzU5OTBlMTIyNTM1MGIgODI4M2MwZjA5YmU3NGZkNykpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGM3YTY3MmM2ZjEyYjE1ZTkgMTkxNzQzYzc5NjE3ZmZhNCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDhlNzliNGVmNjIzYTU1ZjggY2ZiOWVlNTAwOTZhZjkwYSkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDg0NjZlY2NjMGViMWQ3ODYgOWRlZjkwNTY3OWRhN2Y2OSkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGExOTMzZDJiN2M2YjIxOTMgYjQyZTAzMjhiNmU5ZmU3YykpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDliZjJlNTM0OTJmNTA2ZDMgYzU2MWFmNGI5NjAzYTQ0YSkpKSkpKSkod2hpY2hfYnJhbmNoIlwwMDAiKSkpKHNwb25nZV9kaWdlc3RfYmVmb3JlX2V2YWx1YXRpb25zKDljNTA5NzlmYzFlZjdjMDcgNWQ0Zjg5ODRkYjdhY2UxMSBmMTIxODY4NDMyNzZkZjE5IDA4ZGE2ZjliODczY2U0ZjEpKShtZV9vbmx5KChzZygweDI1QkE2NDJCQ0FEMDgzNzk2NkQ5ODU2RTREREYxNzkxNUM4MDEwMkFCRjA3QTlDQUUyRUM4M0Y1MEY4RjM0MzkgMHgzREQ2QzMwQjMxMTc0QUQ2MTBEM0VGRTYwMzFDRDM4MzcyQ0JDREZBNzk5QTQwMEE0RDA1RUIzRURFOTk1RERGKSkob2xkX2J1bGxldHByb29mX2NoYWxsZW5nZXMoKCgocHJlY2hhbGxlbmdlKChpbm5lcigzMzgyYjNjOWFjZTZiZjZmIDc5OTc0MzU4Zjk3NjE4NjMpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcihkZDNhMmIwNmU5ODg4Nzk3IGRkN2FlNjQwMjk0NGExYzcpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcihjNmU4ZTUzMGY0OWM5ZmNiIDA3ZGRiYjY1Y2RhMDljZGQpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig1MzJjNTlhMjg3NjkxYTEzIGE5MjFiY2IwMmE2NTZmN2IpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcihlMjljNzdiMThmMTAwNzhiIGY4NWM1ZjAwZGY2YjBjZWUpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcigxZGJkYTcyZDA3YjA5Yzg3IDRkMWI5N2UyZTk1ZjI2YTApKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig5Yzc1NzQ3YzU2ODA1ZjExIGExZmU2MzY5ZmFjZWYxZTgpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig1YzJiOGFkZmRiZTk2MDRkIDVhOGM3MThjZjIxMGY3OWIpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcigyMmMwYjM1YzUxZTA2YjQ4IGE2ODg4YjczNDBhOTZkZWQpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig5MDA3ZDdiNTVlNzY2NDZlIGMxYzY4YjM5ZGI0ZThlMTIpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig0NDQ1ZTM1ZTM3M2YyYmM5IDlkNDBjNzE1ZmM4Y2NkZTUpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig0Mjk4ODI4NDRiYmNhYTRlIDk3YTkyN2Q3ZDBhZmI3YmMpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig5OWNhM2Q1YmZmZmQ2ZTc3IGVmZTY2YTU1MTU1YzQyOTQpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig0YjdkYjI3MTIxOTc5OTU0IDk1MWZhMmUwNjE5M2M4NDApKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcigyY2QxY2NiZWIyMDc0N2IzIDViZDFkZTNjZjI2NDAyMWQpKSkpKSkoKChwcmVjaGFsbGVuZ2UoKGlubmVyKDMzODJiM2M5YWNlNmJmNmYgNzk5NzQzNThmOTc2MTg2MykpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGRkM2EyYjA2ZTk4ODg3OTcgZGQ3YWU2NDAyOTQ0YTFjNykpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGM2ZThlNTMwZjQ5YzlmY2IgMDdkZGJiNjVjZGEwOWNkZCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDUzMmM1OWEyODc2OTFhMTMgYTkyMWJjYjAyYTY1NmY3YikpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGUyOWM3N2IxOGYxMDA3OGIgZjg1YzVmMDBkZjZiMGNlZSkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDFkYmRhNzJkMDdiMDljODcgNGQxYjk3ZTJlOTVmMjZhMCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDljNzU3NDdjNTY4MDVmMTEgYTFmZTYzNjlmYWNlZjFlOCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDVjMmI4YWRmZGJlOTYwNGQgNWE4YzcxOGNmMjEwZjc5YikpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDIyYzBiMzVjNTFlMDZiNDggYTY4ODhiNzM0MGE5NmRlZCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDkwMDdkN2I1NWU3NjY0NmUgYzFjNjhiMzlkYjRlOGUxMikpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDQ0NDVlMzVlMzczZjJiYzkgOWQ0MGM3MTVmYzhjY2RlNSkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDQyOTg4Mjg0NGJiY2FhNGUgOTdhOTI3ZDdkMGFmYjdiYykpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDk5Y2EzZDViZmZmZDZlNzcgZWZlNjZhNTUxNTVjNDI5NCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDRiN2RiMjcxMjE5Nzk5NTQgOTUxZmEyZTA2MTkzYzg0MCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDJjZDFjY2JlYjIwNzQ3YjMgNWJkMWRlM2NmMjY0MDIxZCkpKSkpKSkpKSkpKShwYXNzX3Rocm91Z2goKGFwcF9zdGF0ZSgpKShzZygpKShvbGRfYnVsbGV0cHJvb2ZfY2hhbGxlbmdlcygpKSkpKSkocHJldl9ldmFscygoZXZhbHMoKChwdWJsaWNfaW5wdXQgMHgxMDQyREQ0ODcwOTI2QUVBMERFOTUxQjFBRkVDMjhCNTRFNjI1Qzk4MzRGOTk0NzIzQjdCQjg0QTkxQjUwNDNCKShldmFscygodygoMHgzNDMyRUE4OUQyQTEyMTk5RDk4M0NCNjBDRDgzNUY1M0M1M0NDM0YzMzhBNEZGQTc1MzU1RERCNzA0MjE4M0E4KSgweDMwOTI1MDhEMUVBNTI1QUU5RTVGMDVBQjI5QThCRkI0NDgxODQwQzRDM0Y0OTc0RjMyRDU1MzgzQzgzMTJFQUEpKDB4MzdCQTJBMDg5MjNDMDJEMUQ0NzNEN0NCODY2MzY5MDAxMDc4MUIyRkJGNzc1OURDNTlBMDY3OURBN0VGRUZGMikoMHgwNDJGQ0UwM0U2ODhFN0U3OTVGODg1QTNGNTkzQjVFNDYwNzQyQkU4ODlGODYwRUQ5MjBDOThBQTRFNzQ3NjgwKSgweDNGRUIyRTgxNTE5NUM5M0FBMjlBMUVGNTk1NDM4M0E5MDA5Rjc0QTZCNDYxNzM4Q0U0RjczNjI3MUFFOEI5QzIpKDB4M0U3MDE4QTlDQzQzOEUxOEExQjc0NDkwMjM1NEZGQjFGQjI0NTJCNTFFRTJDNEY4M0IxMUIwNzkzNkI0NDJFQSkoMHgxRTQ0N0ZFMzgxRjg0QjE1RTM4MUQ1N0MyQjZFNzVFRDA2MEVDMjk3MTgzODEyM0RGRkU5MUNEQUU1Q0E1MkM3KSgweDNGOUJFMTE2NTJGQUE0NTRGOTA0MkQ4OEJCRTJCQjYxMDI1RUFGNkVBNDNDNUIzQ0Y3MzUzMEEyQzg1RDkzNjUpKDB4MTUzMzFGRTg2MkQ4RjlGMTI3MDU4OEZBOTVDQzk5OEI4Nzg3MTRCQ0E0NUJBRDFGOUQ0M0Y5MTFFNEU5RDEzQykoMHgwQzYyNTUxM0U1MDY4M0RDNDlEMUE4N0Y3QkQ3MTA5MDZBQTQzRjRBQTE4RURGMzY3MUZDRTg1NjU2QzI3QkYwKSgweDNFNUZBQ0M3RjhDMTdCREM5OUMwM0E0QkE5NUM3QzAyNkM5M0JDNzEwMjAyNUM4ODVGRjkzMUJDQjIzRDgzNTEpKDB4MjVBMjBERDlENDc0NkRFMDdBOTQ0NTZGM0NDNzVENkI5MTUyQTA2MTkxQTEwNjAxMjg1NjU3MDkyNTU1RUQzNCkoMHgyMjdFNkMwOUVBQzc5NzQ0MzI5MEM3NEZBQUNGRDhEMENCQTNFNDMyQjVEN0IxRjcyNDYwNkZCNkQ2NjQ2MURGKSgweDAwOEJDQjJGRURBMkI4QThCQ0Q1ODdBQjIzODg2QTZGQzcyRTNEMTQ1NEZEOEQwMkFENEQ2QkVBRkMxMTMxMzApKDB4MUNERDVEQjAyODExNkIyOEExNDZEMzNGODEwMEUyRDFBMEQ3OUVDMUVDMjI0RjRBMkQyNzBEREZEODg4RTAyNSkpKSh6KDB4MTBGMTNERTdDMjVCNkE4REI1RDBCRUZBMEZBODVEMkFERjREOUE1NjVDRkE1MUQwN0MzMTQ3NTA5NDU0NTFFQykpKHMoKDB4MjhFNTMyMDE3MjczMTA1QTAxMzkwMkVEQjIwREYyMjcyM0RFNTQ3NTcwOThGQkNCNkQ4NUU2Mzg0OUNGMzE4RCkoMHgyOTFERkRBMTA4QjdFNkM4Qjk4RTFGNjUzNTlBMUUzMDc2QzlDMkU2RjQxMTM3Mjc3Q0QyQjBFREVFRkVCRkQzKSgweDFDRTFFRjU4RjY1RjlERjI0NkEyNDJCMzQzQTZCQjNGMTQ0QzY1RERFMTgwQTE0MDBDQzEyOUNFNjhBQ0RFMDIpKDB4MTU3QTJFM0IxRjc4MDBBMTJEQjMyNzBBNjNFOURGOTg3RjUyM0YxMkFCQTkxMUE2NzM2REQwMTRBQkRENkIzMSkoMHgwQkMwRjUxNURBMkNGNjBDNDQxMzgzOTlGN0YwMDBCNkFDRTUyQ0I3NUVCNDk2M0U0Q0NCNDQ2MDMxNEI4RDY2KSgweDNGRUIxNjA0ODhENTYxNURGNDhBMEM2MkJBNkIwOTRDNjQ3QTVCQ0UwMTEwNDgwNDUxNDVDNEQxRDY3RjdBQUYpKSkoZ2VuZXJpY19zZWxlY3RvcigweDFGRTA5RkVFOEZGNzYwQURDOEQyNzMyMTc0QjI3NzA4MDU5NDlCNDc5M0ZDQjA2ODQ4M0VFRDY1NUFCOUQyRTUpKShwb3NlaWRvbl9zZWxlY3RvcigweDFFODZCRDZGQjUyQUI2MTVBODMyNDVDOTI4ODZFN0MwRTA3MDBCMDI3MzdFQUFBRTc1ODc2OUJERERFNjUzQjMpKSkpKSgocHVibGljX2lucHV0IDB4MDQyRThGRkJDQTIyOEFEMzJEOEJEOUI4NzZDODVCMDg1MzdFQ0JCQzVFNTRCRDk0RUVBMzE4OTNGNDY2MUQzOCkoZXZhbHMoKHcoKDB4MTk5MUUzQ0VCRDQzRUZBOTIyQzk1QjBCNzhBRDczNzM5M0Q4NUEwQ0ExNTY1RDQ3NzRGNEExQjVEQzVGNTk4QykoMHgzMDM0MTczNTUxRUQ4NzIyQkJFMjU0MjFFRUUyNEVERTY2QTA4M0RGQzdFOTk3MDAxMTZFQkRDQTA4QTJBQUUyKSgweDJCRjlEQzhGQkJCMzQzN0RGMDQ5OTUyREU3RTBBNERBOTcyRDEyM0ZEMjVDMDRCQzJEREM3NDcwMTVDMEY1MkMpKDB4MTI5MTAyODNGREJFNkIyNEQzNDkxRkRCNjk0MzBGNzNEMjgxQzQ0MzZDMUMxNTY1MUMzRUM5RDVBMkRDRTAyQikoMHgxNjVBNjAwQzQwMDBDMkYxM0MyMDUwNjA3NzcyNUFGMzZCRDY2MjNDMzIyMjAxN0Y2Nzg5OEYzRDM1MkI1RjgxKSgweDA3NEM4QTMyQTI1MTFBRkM0RjM3OEVENzE2N0I5QTYzODEyNUY4OUI2MzM2RkZENDJERTI2NzY2QzEzQkJGMjcpKDB4MEU1QkM4NTQ1NzIzNDlGNEZDREE4Qzc4MUM0MURENEUwNzg1Q0MxNkYwQkYzMDg0MkU0MjMwOUYzMDQ2MzhFMSkoMHgxMjhFQUIyNTk0MEJDOEMzMkI2MDhBMTQ1QzMwMTExMDYyOTM3Rjg0NjY0NzZEMTcxNkExOUEzNDA1OUMwNUVBKSgweDA4MENGNDQwRkMyNDFFOTM4QjA2QTI3MzQxRkQ0RTIwOTZBQ0VCOEY5RjAyMjI1MTJCRkE2RkYzQTMzRDdGMEMpKDB4MEI5RDI2MENDNzUwNkJCRTBGMUM4RTBCMzNBN0FCMkE3RkUyMUJBRjQwRTQ5RDE3NDE1NTg1NDFFRjg1MjNFMSkoMHgxNjBENjFENThDOTYwQkRCNjBEMTVEMDFCQjMzODQ3Q0VBQUQ4NTM0OTc1RTNCMTlFRTFBQzI2MTY5RDAxRDUxKSgweDI3MTA4NjNBRUI5REQ5RDVEMTQzOTlGRTcxNkY0QzIyOTAyRDJDM0EzNENERThGMDlGNzE5RTk2RDMyRkE0NEUpKDB4M0IzMDk1NDUzMTFDMzg3QjIyRTBDREYzN0VCRUNFNjY5ODA0MTk2QkMwNzdGNDFFM0FBQjlERjQ0MTZDM0EzMikoMHgyNjRBRjk3NURDOTA5NEFCNDFFOEIxQTcwNjQ3MUU5NkY0RUQyMkI5OTcxNDQ2MzVGQUE5QTI2ODNBRTk3ODNDKSgweDNGMDdFOURCNEEzRTFBRUZERUE2OERGN0U3Qzg3MTI1NDI0QUQ5OEMyQzkzMzQxMDI0QTEyMTEyQzk3MDU3RkEpKSkoeigweDA1NzlGNzI4MjE4QzBERkRDQjI1RTRCMjkzQkM4MTk4Q0YzMEVFMTRCNzkyRjM0NDM2MEZCMDQ2QjBDNjg0MTMpKShzKCgweDA2Mjk3MjM0NjkzNTc2QzYwMUZCQTU3MTBGNUZENDI3NEI3QjI3NjRBOEM1REU4MkNDNzhGOUUxMUVDMzM3M0UpKDB4MUIxQjYyRDEwMzQxODZCQjRCOTM5Q0VDOEZDMzM5MTMzQUVEMUVBQzI5NDg4MzYyRTVFQkRDNjhDOTYzNjVGNSkoMHgwQzVFMDYzQkNDQjNGRDQwQjMwODcyQTBBNzBCMTRFNzdGQzZGMzNGNjQ5MkNBODVFMUFFRDE0QTJCQTUxQzVCKSgweDNCMjI3N0MzMUQ4RjdEM0U1NThBNkVDMUFDN0I0QUE2QTY4QzJFNUU3RDk0QkZCNjYyNEJEMUVCODkzOEJCREIpKDB4MTI5MTg0RjYwNEM5ODhCRkJBMTUxMkI5REJEMDA1OTRDQzY4RTVGNzk0MkIzRDk3M0U1RkMwNkIxMTg1OTY4NikoMHgxNTlDREFDRTQxNTg3NDJBOUNFNDNFNDk5NjlBNDRCMDM1MDgxNTI3NjBCMDFFOUNBQzRFQzBEQjA5QkVFODdBKSkpKGdlbmVyaWNfc2VsZWN0b3IoMHgyQTdEMDE5MjlCNjJGMzc3QkEyNUM3QzRGNzZEQjg1QjhGMkQ0RDNGRDJCMjAyN0FBRjgzQzRFNDg0RTEwM0IyKSkocG9zZWlkb25fc2VsZWN0b3IoMHgxRjc3QzM1RUYzRjFEQjAyQkFBM0NFNEE4QzJDQTlENjRCOTE2NEM4NTA5OTAwRkU2RURFMTQ1QTIyOEJGQzE5KSkpKSkpKShmdF9ldmFsMSAweDA5NzI3RUU3QzA2QjlDRERDMEI2M0M2NkM5QzI3REJCMjQxQ0MzRDA4RUU4MTZFNEQ2NzQ5MkZEMzVFNDMxODUpKSkocHJvb2YoKG1lc3NhZ2VzKCh3X2NvbW0oKCgweDEzNDQ2RTQ3MEM5MjZFQTEzQjdEMUZEQjYwMTE1MjFDN0FBQ0QzNUFGNjY0MzQ1RjFCNDIzQTY3OTBDMEFFMkMgMHgwODVENjU3NTBEMEJBMTI4MTEzMDU5NDg1NDcxRTFFNDU0NTAxQzA0Q0UzQzZENzBCRjJGMDYyMEIzQzAyQ0MwKSkoKDB4MUEzMUM2N0REODUxRjFDOEQ0Nzg4MTM0QjQyMDcwQzUyNkFGRUVERUI2NThBMTI1N0NFQjAzNDFEMjY3N0UwRSAweDMyODk4NUI5QjI5MDYyRkNENkMwN0YxRjM0MjcwQTY3ODdGRUJFMThBNEY5OTJCQjQxNEZDMkQ3RTRCRDVBMDUpKSgoMHgxMTJBOUI0QzA4NDE1RUEzNDQxOENFQkY1QTdFMDQ5MUNDOUIyRjJFQjY3NzI1NEE5N0I1MEFBOTQ5NTM1QTQxIDB4MERCMUY2NUQ5MDM1Nzk1MkNCRkI2QzlGRkJDMDZCQTZDN0M0RDRBRDlGQjlDMUFBMkQxMUE5NjA3QTYxMzU0NykpKCgweDIzNTBCNEQxRjlFODhEMkRBOTc3REQwQ0MxMDU5NDVBMjE3NzU5NDI0MkJGQTE5N0NGNzAzQ0MwOEI4MjJCM0EgMHgzMjM0NDJEOURGOTg2QTM2OEYyRDc1MEQyNzYzMkFGQTcwODYxMzEwOTBBN0M2MjA4QjM3MEE3RjMyQjcwOTEyKSkoKDB4MTUyNUJDMkQzRDFERkUwQjBGMUJERjdFNjQ2QkE0NzdDMTFBMzUzNDE0Njc4NjVFN0U2QTkxMzRFRUI3RDMwQyAweDM3QzVGMTgyMTlEMDMyQTIwNzlCNUY4N0U2OTYwRjczNTE5OEVGNERGRDlFQ0JEODE3NDJDMDcyQjNCOURFNTkpKSgoMHgxNzVCODNBNTg0OEY1OTkzOUI0QUFBODlCRjM2MUQzQkE4QzY3NzI5RTBDOEI2REY3MDNGMTNBRDgwNzhGQjI2IDB4M0JFMkYyODY2MEFCM0MyODRCMjI0QkRFNjM0RDMzQjZFRjZFNzBDNDJBQ0Q0NkNGRkY3QkY5ODE4Nzg0QkY4QikpKCgweDBCQ0I2MTZBMzcyQkRCNTU4ODA1MzVBM0M1RTIwRDJBNDdDMDY1NTFFNUZGMTlFRDQ1ODQ1ODc0ODRDQ0YxRDcgMHgxRTNCNzYwMzU3N0ZGQjE5RTdCRDI2NzhBQjNCQTM4MTkzNzlEMTA0NDI3NzBCOTk4MDRBODdBQkZEMDUxQ0E5KSkoKDB4MUVFRTQzQjNDQzRDMkJGNTk3N0JEOUYzMzY5MTJEMjVDQzM3NDUxQ0FGMzBGNDYyRjc2MkU5NDg0NzkzRUFBNiAweDIxRkU5Njk5MjYxMzZFREM2RjZCMTlBQ0QxNTg1RURDNkIyNjNDQzU4MEM1NTQyOEJGOTI0NUNCMUU0MDY5OTgpKSgoMHgyNzk2RTFEQzc3MEMzRUU2QTA0NDg4MUFDMDc4NEMyQjhBNkY1RjBDNjlBRTA1NjNFRjI0MjdFRTRCQzE2NUQ4IDB4MzZEQzY4NTFERTZDRkU5Qjg4QzhFQTIxMzAyQUI0MzA2NTk3RjczNjNDRTM5ODY4QzI5NjAxRjUyNjdBOTQ5OSkpKCgweDI3RDYwREVGOUVDQTA1MjA1NEEyOEY5MkYwOUFFQjVBRDQ2OEExQTMxOUM5QkE5QUNFREUxQUVENjI0NkFFMzUgMHgzNUFFMTFDNDFCNDRFNjJDODIzRENEQUUxMzEwMEJDNzM5OTU0MkI3N0MyNjFFNzIwNTg0NTlGMjMwN0ZCQkY3KSkoKDB4MzIwMThFMjM5QkVEODkzQzRDREJERkUzMENENzVGRjM5ODk5QUQyNjI2Mzc2OEEyNkJBMkZEQUVDRjFDMEQ0NiAweDEwRTMzNzg1MTVCMzg4MzVDNzNEQUY4MkJENDg4Q0U5RkU3RjdCNjM4MkU3QTU1RTUzQ0Q2MzI5QTREQTA1RDgpKSgoMHgzODZFNjhCODQxMUEyMTExOTYwNTRERUVEOUI1MkMwNDVGQzM1MTY0RDMzMDQ4MzYwQTUxNzY1RjkwMzNGM0VFIDB4M0MzRjg2RTM5NjU5NzM4Qzc2NTAyMjk2MkU4QzMzOUVCNjk5RTI0RTY1RjFCRjExNDc5MjE0MEFGRDA5NUJGQSkpKCgweDNEODNCRjY0MTgwREY0OUU0ODc2MzY4NEM5NzYwNjE5MjM1Mjg2MzA2QjRCMkMyOTQ4OEYxRTFCMkEwNEMzNDYgMHgwNEI2QUFDQjA1M0JGOTBEQ0Q5QzU0ODRDNjBFQzUwNTU2RjY5RUYwNTZDNzFCMTA5ODhFNEY5ODNCNThCNUU4KSkoKDB4MDU2RDBCNzYyOEQxQUVBQTk1MTI4NTBBREExMjBGMEFCMkQ3MkUyMTFCMjk2OTBGMzlBOEZERjQ5MTRCQkNCNyAweDAwMzdDNzA4OEMzRDRFQUM4REUwMEJCOTYxMkI3RThGRjUzRUU4MzRGNkQ1NjREN0E1OThENEFDMDMyNzRENkIpKSgoMHgyNzNGMzg0OEZFRTJFNkYzMUU5RDIyRUU3OTFGRTNEOTEwMjVEQzQ5QjJCN0IwNEU0Q0ZCQTI2MzU3MTBDQzFEIDB4MDBDNTFEOTQ0OEUwREYzMUFCQTFFRjQxNUJBM0I5NDlCMEEwM0RDODRERDEzRjE0RjZDRkI5ODI1ODVCNjkyNCkpKSkoel9jb21tKCgweDFCNzdFOEFCREI2MURCQUQzOTNBQjMxRkUxRTA0ODg0OTQzMTk0MkU4NEY2QjdBMEExOUJDNDZDNDJCOUE0RkEgMHgzQkIzOENEMjlCMEE1OTQ4QkM1QUU3MTI1MUU4Mjc4Q0U2MTlGNEE5RjQxOTBCOEZFM0Q0MkI0QzZENEE1M0E1KSkpKHRfY29tbSgoMHgyRjU5NkI0N0ExNDBEMDc5QkZERTM5QkU5Qzc0NDBDMkRGOEUzMjREQ0Y0ODBBMkNDMTM2M0VBQzQ0NDVENTVBIDB4M0YyMTQ2M0Q5OUFCMkJBNTlCQUZDMDI4MUU0QjBEQ0MwQkNDNURDNDlBNzRGMjA1QzJEMkFBRDkwQTBCQ0E0MCkoMHgyMEJBMjBBRDJDQTJFQjBEMUQyMzcwOTAzQURFNzQwRDdDODZFMjA2NzY0NEMyOUY5RDJDQUMyNDdENEY1RjI0IDB4MTNGRkY2MTEyOEMxNjk3RTcwQjM0Q0YwNzEzN0M3N0VFNjdBOEU0QjBCMzM5REY5Q0M5NDA4OTJCNzUzODY2QykoMHgxMTRCNTQ4QkU5NUVERDc1REVDMjQ4MkE2RTUyOTcwQUNDNUU2MjgxQjM5MTlGMThBRjkwMTk0N0UxNkQyNzdDIDB4MzcyQTA5RkMzQ0EwRUE2QjA3Q0JGMjA4MDI5NUI3RkI2N0Q1NTY0MDBBNTVGQjBFQjUwQUQxOTlFQTc0QzFGRSkoMHgyQUFCQ0FBN0NEN0ZFNjY1QzA3RjVFRTgzMUExQUJCMkNDQ0E2MzhDOTgwQUFCRDRFNDE5QTdCRUIyOEExREZGIDB4MzgzMkY4NEY2Njg5MUZERDhFMzZFNDI4ODNGQjgzODJCRjFGQTdBRDc4RUY0QkQ5OTg4QkNEMUM1RjY4NUIyNCkoMHgwQTI0QUEwN0EyNzlCMzA2QUJEMDFCQTMxQTJEOEYyQzkzNDczRTQxMkE0NEYyMUU4QUI2QTUxMEMxRDk0MzUxIDB4MjE2REQxMURCNEVBMkE4NjFEQzM1Mzk2QjZGNDE2RTkyRjdEQkMxRTM3ODE2MDZDODIxMDg5Q0VCNjUyN0NGOCkoMHgyREJBNTI5RkZBRTQzMzg3NjEwOTAwNjEzMTgwNDEzODQ0MTlCQzNEM0EzMUYwNTAwMEY1QTc4MDQyQzQyMjBDIDB4MzA4ODY2RDQ5NjgwNjlBQkRBNTc4QkQ0MDQyOTE5RkNFN0Q1MEMyRkY0QTRCRjBCRjBDQUE5QjQwMjA1QUI5OSkoMHgwRkZENTczRjk4QTcyNENDRjU2RDE3Q0E3QzAxOUJBMDY3OTJDMzAwMTA3QUU1NDY0ODY1NUM0NzNEQjk2NUREIDB4MTZBMEMyMzg5RkNEM0RFN0Y4Mjg4N0I0OEIxNTM4M0FEQkI5OUYwMkRGMDc1QkMxNDc4Njc3NEJCN0ZGMTQ3RCkpKSkpKG9wZW5pbmdzKChwcm9vZigobHIoKCgweDFFQ0U4OTQzOURENDdDRjVENDlDMjI5OTZDRkExRjUyOTNDNTZCODQwMERCODlFMjQ5Q0RFM0VFNEU4OUYyREUgMHgzRUREMUI3MjJFMkQzRTM4M0Q4MTkzRERCNjdFRkQ0RTY0QzlCRDFGMTYzQUFFQkFENUYyNjE1QTFBNzE2RThGKSgweDM5OTVFRUU2OERFNTdDNjc2Q0Y4QUU5NEY1RTlCODQ2MTA3MTEyNTc0QzkwODc3MkUxOTQ3MTFCMzREOUZEMEEgMHgxQUM1QTE3NjUxMTMwNTE4NkJGNTZCNkUzNkRENjJERjQ5Qjc3NjYzNDBDRTBCM0I5NkZFNjA3NEJGM0Q5RjNEKSkoKDB4M0U4RDJDRkFGOEIyOUUyRDAwMzRDRDA3OTlBMjJDNjhEOTY3MzExNDU4MzJDQzVEREY3MUYwRUVBQUVBMUNDQyAweDI2N0Y3RDI3QzM1OTVEMzMyMjhGQkU5MzA1QTA3NUZCOTMzQzdGQTcyNzI4QzI5N0ZENDQ0Q0U1ODhDMkM3MUEpKDB4MTNBRERDREE4OTZBNDUwQ0YzMUZGNTVDOUFFMUU4QzE0QzdGOEJGQzNGNDYxMDQ2RUJGNzkwQUI1NzRGNTZEQyAweDMwNUVDMTZGOEM2NDUzNTgyNzQ2MDhFODE4QTlBQ0I1NEMxRTlDNDc5RDE4NDkyNDNBNUEwODE5RUYwQjcwOTQpKSgoMHgwOTY0MUQyMDdBRjA4RTI3QjRDRjE5MzE4RkJCOEZENzZEOEQ3RTY0MkMxOENCOUU0QjFFRkFGMDVDRDZBQjNEIDB4MDVFQjFBODg2MTE3MUQxRDI1QTVCQjAxQkJERDBDODRFOTdFNDlCNDA2OUNBNEI4NUI3NDZFQzdDQkU5Qjg3RSkoMHgzOEQ1RDA4RTRGQTE3RDhBOTFCMDIzQjMyMTg2RUU2M0I5Q0ZEODZBQUYyMkNCNjZCRUU4QkNDNzU1NzdBMjdFIDB4M0RCNDQyQjBENkUyQzkwNjJCNzJFNTVCNzY4RjcxQzc3RjNCRkE0ODEzNEQ1NTQ1NTc5NUU5RkRFRjcwMTU5RCkpKCgweDBBNkFCNUMxNjU1QTVBOEU5M0YxMkNEQUY3OUMyMzI3RjEzRkU4OTMyQjQ2QUM5NkM1OTIzOTYyNEZCMjdBQ0UgMHgzQjc2OEFENEI2REY5MEQxNTlEMjVDNUMyRUQzQjY0RjdCMDJEOTJDMjExQjExODI3RDk5Qjk1RUIyNkZBNjQxKSgweDE4NDAzMEY3MEIwQzlFNjQ5MUFDRjdBMUEyMTE2NkY5NDg3RTlEQTdCNEI3MkNEQ0M1MjQ0Mjg4MzZCNkJGQzMgMHgyQjQ5MTg0RUU3NkY5NUI4RkY3NkU5MTVFMzE0M0E4RTQ2NjJCQzE2MTAyN0M5M0M0N0E5REQyREE2RDEwNUYzKSkoKDB4MjY1QUJCOUFENzU3QTg5QTgxMUE5QjY3NDIzODE5N0NCNUY2RjMyQTc5RjNGRDMwRUMyQTQyNDExRUMyMUQ2QSAweDExQ0U3NDg4MUZDMDM2NEI2QUQ2RTE1MTg0MzZBQ0VGRTAyRjlFNjYwODhGNjRBQkY3NTkxNDIzNUEwMzVCQTMpKDB4MUE1RTI1NDY5RkFCRTJFNjhFQjc5NUM0NDhCQkM5MzZEQ0IwQTEyODYzOTUzODI0QzIwQTMzQUZDNkFEMzc1MyAweDEzRERCNDIwRUY2QzY2QUM3N0JFRTc0NzRCNkI1RkJFOUVENTVDNjA1Q0EzQjM1QTQ1QzlGN0QxMTAwQkY5MkUpKSgoMHgyRjNENEE5RDQxNEJEM0Q5N0U5NUE3NUI5NENEREY3Nzg2MDU4QkYwODgwMDBFMjBBMjg2RTkzQjc5ODE2OEM2IDB4MjFEODI2NUNBNTQ3QzhCMkRCRjhFOTkyQjFBQ0VFNDI5Qzk5MEVFRDczRDQzNUM1N0RCODc4Njc2MkNENDI1RikoMHgyMjY4NDJCNURFRUNGRjIyNzNGMEFBNTY5RUYwNUM0QkREQUY5RDA3NzIxQjc2OUJDRUZBMTFBMkMyODNDRDIyIDB4MEY4RDk5ODRCQzg1NTlFMEE5MkUyRTk1MzM0NDQzRUZCNTdGNEJBRkJENDgwNTU1RTcxM0Q5MTk3OEY3MTEzRSkpKCgweDJGMEY2REYyREU3NEYyMjAyQTJGNEQ0OERFNzMzQUQxMDA2MzA5RUYxMzBDMDhEM0EzRDBCNkVFQzE0NUI4NzggMHgyQjJCNjlEMkExODhGRjBDQjE4RUVBRTJDNEFDQTI5RDI3N0E2MEM2MERFQUY4MUU0MzhCOUQ4NUFGNTA5MDFBKSgweDJBRjk4QzgyRTlFQTM4NEJBMkI0RTZDRTkxQUVFQjVBREMwREFDMTVFMTMzMkM4Qzc2QTc0ODI3MDFCNzI5OTUgMHgwNDEyNDYzRjVGQzExMDUwQzc2NjRBQ0FCNENENUQ4RDhGQzhDN0Y4RENGMUNDOUNDQkUyQzQ5NDQ2RDhBOTU0KSkoKDB4MEEyREI1QzJGNENFQTVDMjVGOUVDNDkzMzEwQTgxM0I3NThGNjg5NDQ5M0Y2OENDOTBDQjU1NzM2OUREOTRCNyAweDJBNTU0NjI0QzM5NUY2NTg1OERDM0EyNjM5OTFCOUQ2NjgxMkU3MTg0MURGRDAwMjVFN0ZGQTc4NkFDQTQ3QzEpKDB4MUUwNTI3NTNDRjhDMzQ0NUVEODk2NjMxRDU3QjNBNTRDRDExNzBFMDI2MDRBMDJGMjk5RThBRjZGNDIzNDFCNSAweDM3MkQ4MDFERDY5Mzg3OTI0NEYxQTUzRDQ1NDkxRkQ1QjMzNjgyRTZCMkM5RDAxMkQzQTRDNTFBM0U1QTY2RTIpKSgoMHgwRUI0NEVGRTFDMjM4MERCNkJEQkY5OTkyMjAyQzc4MzM0OEYxNzMyOTdBNzZDM0IyMEFFM0VFMzRGMUQ5MzlCIDB4MjVGQzZCNTY5NDYzOTAwRjREN0Q2RTU1RUIwODc0REUzRUM2RjY3MkQxQzlFMEVGODFDMDg5ODFENjEzMjZCRCkoMHgxRkJFRTdDQzRFOEIwQzE0M0Q1NTI1NzZERkE0QjhGNzM4OTIyOUIxM0Q4MTk4ODc4QjY0QjI5QUIyNjM0QzUwIDB4MkI3MkYxODZDMzc5QjMyMzgyRTczNTU0N0YxNDVEMDQzNDQyRTI3Mzk2NEY3MDAxNzg3QkUwODM0N0U1MkY5QSkpKCgweDJDNkVEMEZERDA2MzNGNzNERTczMzYzM0YzOUE3Q0U5ODE5QjQwMUIxRTQ2MjZCM0I4NTRFMzY1QkUwRjEyMzEgMHgyOTJCMTBFMEFFRDlEMkU0N0U1OEFBODgyRTNFQUQyMjdCQjVBMUM4RDY3RkNBNDI3MjhBQUNFNEQ0MjI2RjlFKSgweDI0QUEyRTFGQjVGNEQ4QkZBN0RCQjk3REIxNkE4RkU1QjJCNzBGNDUyREM2QzYxMzMzOEMyOTVFODg3QUMzMjQgMHgzN0JFNEQyREEzQzA0RjgwMDEwNkQzNzg5NDFCREEwQjE4RkJFQTUxNzY2NTk4ODU1QUI2NEFBRUFCRDZEOTFBKSkoKDB4MTk1QkM1MTI2QkQwNTM3NEM4M0Q0NTA4OTgwQjZFRjIwRjc4NUIwMUUwNjgxQjMxMTZGOTFCRkYzMzU5MzI1NSAweDA2NkU2MDAyNjM2MjgzQUM2Q0EzNzk0NTBFRDY1N0NGOTk0MTk3QTJCMDQxRERGMTQxNjA2QkFDRkUzNDc5Q0UpKDB4MzA0QjgxNUZDNzQxOEZGRTk2OUYxNDczQTY3NDAxOUVENUFGMUU1MDFBMUU4QTgzNUUxMTE0REU3OUNGNTc5RCAweDFBODBFQTI5MDUwOTI1OTA3Q0YwRERCMUY2ODNGQjUwQTcxN0VFRjM1NEQ5QzM3QTkwNTc0MUU1NDVEQUJGMDQpKSgoMHgzMjBBODQ0Q0ZFNkFGMkNCRjk4MDBGODQ0RjMyRDhDQjJGNjg1RUY5NDNENzcwNzE0QThGNTAxM0RFM0IwRDczIDB4MUNFRjA1M0M4QTJFRDUwMTY3NUFFRjAxQzUzOTIwRjREODYyQzg5RENENUMwRTAxM0RENjY2RkU4QUQ0ODdEQikoMHgwNEZGRjAzRERBNUI3NDY2QzE5ODc0NTFBOTI4NDA3NDNENDUxQjdFOUM4MzNDMzU4Q0RGMzRFQzA1RUU5MzMzIDB4MzY3MTMzQTFDMTVGOTBBMEExNDQ5MkQzMTM1Q0REM0FDMzM5OTA4OTUxMzk3NUZGQjI5REQwOTcxNDE3RkU1MCkpKCgweDBDNzg5RjQ2QkVEQUNFQ0VCNDMyMkNGNDFCNUM2MzA4MTExOThCNkM0QUQ1OEY1MkYwOTZGNjczQjY5MUU3OTEgMHgxNDdEMzVGMjYyNjc3QTBFMkM0MDQ2NjI4Qzc3QzBCMjE4ODA2QjFGNjc0MjhEQkI2NTdGREMwRjAwMkJCQ0ExKSgweDA3NEVBMDE1N0Y5NzM1RTY2MkU0ODM2MjdBNjQ3MzIxQzRDOTk1NUIxRUZEQkQ4REExQUM4QUQzQ0RFQjA2RDMgMHgyMzdGNTk1QjQ1OURBNTFEMEY4REQzRjE4RTZFMEVDMUVBRjI1NENDNjJBQjc4QTEyQjQ0Q0VFMzY2REVBNTY1KSkoKDB4MEM4RDk4NjAzNjBFNjU5MEI3MjAyNjM1REU2QTdBNTNFQzA3MzJGMjAwMjgyREQ0Q0YzODkxMDg4MEY4OUYzNyAweDFDRTI2RTFGNjJFMzA2Q0JCNzc4NEY0RTRFMTU4Qzk2MzU1Mjc5MzkwNEZCOUJBQTAxRTM1Q0NBNDRFNDgzOUYpKDB4M0IyMEQ2MkM2QTVEMUU4MDlGQ0QwMTE0RUI1M0M0RUY2RTBBM0ExODE4NzMyNjFGMUVGNTVBNkRBQzVGNDY0RCAweDA4MEIwN0QxNzMxMDFGMTRBNEIwNjlFQjYyQTM1MEY2NTg4QzQ5NzE0NUZCQTk4MTVBRUM5MTg3QjVCOUI5RTYpKSgoMHgwRjMwRUI4OTZCRUY5OEI0MDYyMDIzQTRDMTY5NTkzODY5Q0Y1Q0E3QUUzN0IwNjQ2ODA1Q0VERUU2NDBENjk4IDB4MUE5OUY0RkVFQzIwRDQ0QTcxQUNFMTBDOEE2RjlBMDU1NjkyMEE3RUI3OEEwRkNEOTEwRjMwMzE2NUJGMjEzNykoMHgwRDIyRjBGRDg1RjY5NkE0NkI3REEwQTU2OUI3NEI5ODhBQTZGMjcwRkI0RERERTI5NUZBRjRFNjYxOTI5MEJGIDB4MTg5QTk3MTVGOTEzNEZFMTU3QzFCOTYzNjRBNTk5MzE4NjVGNkQ2QjcwODgyOEM1MkZFNkZEQUJERjVBQjVBQikpKSkoel8xIDB4MEQ2RDdDRDk0MjFDQkFBMzlFMkE4N0JBNTY1QjUxQkM0QjY0RDdFMTg5RUJGQjVGRDIwQzYwNkU5NDBEQkREMikoel8yIDB4MEMxMzdEM0I0MUNEQkY2N0Y4QzUwQzdFRDcyODZFNDE5NEU5QzE3Rjg5REI0RThBQkUwNTEwMzEwODFENjY0RikoZGVsdGEoMHgzNUZENkIxQ0QyRkFEOEY2QkREM0ExMkYzRDhFNzgwODBGQzAxNjkyODhGNTU0RDM5REExNUI0Mzk1MkVBOEMzIDB4MkQ4MDE4NDIxQ0E4NENBQkQ3ODM3NTBDN0JFQTc0Rjg2NTdENkIzNEY5MEZCNjZCMkJBQjJBQjA5N0YxODE0OSkpKHNnKDB4MkFBODFCQzUzMTI2REFEQ0I0NjhBMDRGNjQ0QTE3NTMyRDlEQjQ3OEYyQjFGRjY1MjU3MTY1QkFBQTg4MEYwQSAweDFGNzUzODQxNTIyRTYzOTI5NUNFMzJCOEZCRDBENzBGQTJFMzc2RjBFNTc1RTZDQTEwNDFGMzA4MTNDMkVGRjQpKSkpKGV2YWxzKCgodygoMHgwNzZEMDNEQTkyMkMzMjQ4M0FCMUVEMTRBRkIwODVGNjNGOTFGODA2NjhFNjM0RDg1RUNGNjhFRjNBRURBNEVDKSgweDAxN0I0RUI1Njg0NDJCQ0EwQTQ3MkNEMkJFMTA1NEIxNzU0MEVBNjlEQTMyMTZBRUU0MzgyOTYxMjQ4MDM0OUEpKDB4Mjc3ODI4RDIzMDY4ODRFQjM4RTFENDc2RTE5MTMwNDA5RTY4QUFGM0Q3RjQ4OTAwODIyMDI3NDYxQUE1RDA0QSkoMHgxOEJDMDI3QzAxMkVDRkIzOUMzQUEwNzg2QTZBODM2N0FENjU4Q0IwNkY3QTA1MTAwRkM3RUQ1MUZFNDk5NTA1KSgweDJEMDhEOEQ3MjhGOUZDNkQ3RDY2MTMzMDUzNDE1ODMzMkQyNTczREY4N0FDMzk3QzA0NTk5NzA5NkU1Rjg4MzcpKDB4MEM0Mzc5NjNFOTZERDg2RTZCQTUzN0Q1QUExOTg3MUJDMzVCRTZFQzI2OTMzMkZCNjRGMzI1NzUzMUMwMDExMykoMHgzRjMzQTU3Q0I1OUJEMDMwNjUwOUM5NUEyQUQ2QjVFOEE3RTk1MDA4M0Y5NzZFMTkxNTFBQzZDRkIwMUNEOEYzKSgweDNBN0Y1OUZEODdDRkM2RDI2ODcxNTZBMzM0QzA0RDY5NDcyRUUzQzVGNUFFNkJGM0ZFMkU1RThFQzJFOUUzQUIpKDB4MTRGNTY3MjZDNDlDRTcwMjg4NkZDMEY2OEEwNzNGRDY5QjJFRkM5RjcxM0Q2QUU5MEFGQUVCRDRDMjk2NEE0MCkoMHgxRjY1RThERkM5RTZEQjQ2MDhENEI4NDgzNzkyNTRENkIwNzNBQzQ3NjY1QTg2Rjg2ODI4RTZDMEVENTBGMDkxKSgweDBCNjA1NEMyRkEzNjA4RTlDRkM4RDYwN0U5N0U3MUUxNTcxRDIzQzk0QUY1MjgwM0E1RDVGRDFBNEUwMzYzOTUpKDB4M0U2RDU1MDQ2RDM5RkQ1QUNFNTdDRjc3MUNGOUNEQzE4MENGRkM1MUVGQUE5QUEwRDcwMEFGQ0IxNTlFNzU3RSkoMHgyQ0E5OTNBQTY4MURCQTVFNTg2QjA4QzlDRkIwMjAzNDZFNDhFQTA1REM5OTA1RUM4NUNBMDlGQkNEMzJERTZBKSgweDBCOTJCRDVFMjJEMTM0MDhBRjdCMDRFMzU2MkY2QkExMkUyMTgwODM5Q0Y3QzZBODhEQ0FDQTFCMzRGNjREQUQpKDB4MEU2QTZCNjdDQjVDQTg3MjBGQ0FFNTFBRjQwODkyNDM3RDUwNDNBNTgzRENFMkI1QjMzOTY2NUY0QTk3Qjk5MSkpKSh6KDB4MDY4Q0I4M0JEN0E4MUUzNjM1M0NCNzZCNDA1MjA5MjlCM0E1MDM4NTJCMjhGRTdFMTlDQjA0REEwQzI5NUVCRCkpKHMoKDB4MDkwQjMyRDY0NEUyMEUzRTcwODJCRkQ5ODcwNDdDRjA5OENDMjFGMzM3Nzk0RDNCNzg3RTA3QTU2RkE5QUE0MSkoMHgwNDE1OEQ2MjBCMDA2M0VDMDNGODA5MjM0MDc1MjFBQ0I5NDI2ODVGNTk0Q0FGNUM1QzNGM0RCM0RFQTQzOTVBKSgweDM2NDU0MDRBNzBEMDExQkQ0QjQwQzFFREIyRjJCMjA1RUI5RDc4NDU2OTgwMDkxNUU5NTExMzRCNDlFRTE4MUEpKDB4MUI2NzlGRDUxOTgyMkEzODQ2MTU0RjA5NThBQTUwMkU1NUYxREVCMjI5NUI0NEI2N0ZEN0EwODdDMkVCODlDQykoMHgzNDkwM0Q0OEM4NEJENEQ5QkYxRUI4RjZEN0FGMTMyRTJEODVCNkVDQkI5OTRDODM3NzEyMERGQjU5OEEyOTUzKSgweDI3REM2NTVFMzg0NzhEMjFEMjdDNTdDQjMwOTQ2RTlCNjkzRjQxMTM5NDI4RDQ1ODEyRDY5MjBFODlBODhCMTYpKSkoZ2VuZXJpY19zZWxlY3RvcigweDAyNzc0NzM4QTM4NUI2MEZFNzkwMzZBN0FCOUNEMENDQzVGMTUyM0MzQjRCODI0NzU1QzEyMjVDQTRFOEUzMTMpKShwb3NlaWRvbl9zZWxlY3RvcigweDMwNTRCQTAyNjU5MzJGODc4MTBFMzlBMUU4MDZGMTU4RTE2REZCMEE0NzVBNUJGODgxQjE2MkVFMUVBNTI0NjcpKSkoKHcoKDB4MkFDN0I1NzU3MDdDRjE4M0VCNDAwM0VFMTU5N0EyRjBDNjFCN0IyOTc2RTFGMzkxRjgzMDdERDQwODA0ODM3RCkoMHgxQjU4MUQ2RDQ2RkUwMUVENEFCN0FEMEVEMTdFNkMxOUEyQjUwQjMwNUJGRDgyMTg5MUE2QzlEMEU0MDY1RTNFKSgweDFGODYxMzFFNURCOTFGQjY1RTI2ODg2NzZDMzhGQzNERTkwNjVERDQ4M0I4MzAyQTc5NTFDMDk3RTFDMjc5RDcpKDB4MTFFREU5RkM4QjA2RkJDRTlBMDE0M0I5Q0NDN0I3MjAyNjQyNUQyQjA3NkU5MzczNjA3MTMxMTgyRTM1MTAzQSkoMHgzMDcxNUVFMjk5NUQ4NjAzRDI5OEQ4MjAxRjdGQTkyMTc3QUMzOUYyMjlENTU4Q0U1MkE3QTdCMzdDRTVFM0ZCKSgweDI5RjMzNDJGNzkyMDkwRkVBNkUxMzZFODg4QzVBREQ4NkY3QzFFNkFENkIyN0E1Mzc0QjMzQTVFRTlCRTgyMTMpKDB4MDM4ODBEOTdFOUQzNDFFREQ5QjM0RTBCNjI4N0ZFRjI3QkZFNUJCRUE1NjQxRjUyMzk1MUNCQjI1QkIzRUJCMykoMHgzNTMxMzUzQzQyMjgxRDU4RkRCMjc3OTA2QUQxMDIwODY2Rjg5OEE4RTE0MDNCRDA4NEQ5NERGODA5RDQ0M0E1KSgweDJFOEI3QTk0Nzg5Rjg3MkJFRUU2QzY5N0NFNzFBRUEwMjM1RDc1Mjg4OUQ0ODQ4QkVDODAxRTRBNThDNjE1NzgpKDB4MTMwREFERjU1OTQ0NjdCNUVGOUFGQUNFNTVGMTkzMjQ0RDFCQzU2OTcyQ0M3MTk0RjcxRDkzQTBERDhFREMxRSkoMHgzNkQzQTVBOUE0Q0REN0NDRUEwNjRGQTc3NTI1OThBNzJFRDEwNEFEMTFDQkE0NUJBRTVDQjc0RjJENzE4QkFBKSgweDIyNzdEOUJDRDFEMUFDQjVBMzY0OTNGMzc4QzIzRDc3MDgzM0ZDOTg1MDlCOTk1NzlBMkI2NTYwQzRCMDg4NUUpKDB4M0NGMzZCMzU2RjE4NjhENEM0NkI0OTMxNEI2MTY3QjA1QjkwREY1RDE4NzMwNTE0MUZCRDkxNkYwNDVCNjIwNikoMHgwNzREQTY0RUZEREUxNkU0RTM4QTU5NUU5QTQ0MDA3OTU5MDE4Nzg0OTMyNTIyQzJEN0RGMEE3ODZCMUMwMUZCKSgweDM0NDYzMEM1Qzk4NkUxQUFGQzJENkQ4MzZEODY5MUM2OTZCN0ZENzlDRDA5NjNEOEI3RDU5QjYxRTVFQjFEMkUpKSkoeigweDJDOUMzNTVFOUIyN0FEQUIwQzRDMzBFOTI5M0U4QkZBMkNCNDdBRkZGRkNDODBCNDM1MzJDNUQwOTBENjEzMTEpKShzKCgweDMxRUJFRjkxM0RBRjVBNzRENTYzMTVEMzA1RjM3N0I2NDJENjY1NTMzMUYxNDI2NzMwQjFBMkQ4NEMwOUVGQjIpKDB4MDFBRTc1RjdENTAyMzEzRjg4MDBGRUM4RUIxMUJDQTc4M0JDOTM1Qzg2NkI0ODU5MDk2QkZBMURFQzk3QkVCMikoMHgyRjQ2REE2RDFCOTJEQzcyM0ExRDQ1MDVDQzE1MjVCQUU2MUY2RjA1MTAzNUEyRURGREY2ODdBQ0REQUM2OTRFKSgweDA1N0NFQjFBNkNBMzRCMDBBRUQxODQwQzI5Qjg1NTQ4MzRFRDYxMzQxRjU4NkFCNjlFMzUzN0I3RkE2Mjc4RjIpKDB4MkFCRTAwQTBBMjI2QzA1OTRGRjI4NDFCRDhFN0UxOERGNURCQkJFNzcxQjU1MkU1OEJENDc4QzBGNkQzREFENCkoMHgzODZFRTk0Qzg5RUEyQ0I3REI1OTMzMDQ5Q0NFOTA2QTE1MTJERTY2RkNEMzFBMDI5MkQ4M0Y5MzM5OTlFQkY1KSkpKGdlbmVyaWNfc2VsZWN0b3IoMHgyNDI3NkI4QUY5RDkwOTFGQ0RCOUI0MzlENkJENThBN0JGNjg0N0JEREE1RDRFQUY0QzBCRDI4Qzc0RTlDQTg3KSkocG9zZWlkb25fc2VsZWN0b3IoMHgyQkJFMzJBRUUzOThFQ0M5QjYyOTE4OTc0RDIzMTFDRTlGOTA0MkRERjczMEM2NDIxNzk4MkU5MkIxN0MxMUVCKSkpKSkoZnRfZXZhbDEgMHgwMkRFMzREQkM0RTA0NUJFNjQzNDlCRkE2M0FGRjRFOEU4MTlDQkYxNkI4QzYyMjIyRkZCNTgzQTQ2N0IwNUJBKSkpKSkp"}}] })
}
  
```

Account state after the above transaction is included in a block

```
query MyQuery {
  account(publicKey: "B62qmQDtbNTymWXdZAcp4JHjfhmWmuqHjwc6BamUEvD8KhFpMui2K1Z") {
    nonce
    snappState
  }
}
```

Result of the query

```json
{
  "data": {
    "account": {
      "nonce": "0",
      "snappState": [
        "1",
        "2",
        "3",
        "4",
        "5",
        "6",
        "7",
        "8"
      ]
    }
  }
}
```

#### 3. Update Account Permissions

A snapp transaction to update the account's permissions.

```shell
$mina-snapp-test-transaction update-permissions -help
Generate a snapp transaction that updates the permissions of a snapp account

  mina-snapp-test-transaction update-permissions 

=== flags ===

  --current-auth Proof|Signature|Both|Either|None  Current authorization in the
                                                   account to change permissions
  --edit-stake _                                   Proof|Signature|Both|Either|None
  --fee-payer-key KEYFILE                          Private key file for the fee
                                                   payer of the transaction
                                                   (should already be in the
                                                   ledger)
  --increment-nonce _                              Proof|Signature|Both|Either|None
  --nonce NN                                       Nonce of the fee payer
                                                   account
  --receive _                                      Proof|Signature|Both|Either|None
  --send _                                         Proof|Signature|Both|Either|None
  --set-delegate _                                 Proof|Signature|Both|Either|None
  --set-permissions _                              Proof|Signature|Both|Either|None
  --set-sequence-state _                           Proof|Signature|Both|Either|None
  --set-snapp-uri _                                Proof|Signature|Both|Either|None
  --set-token-symbol _                             Proof|Signature|Both|Either|None
  --set-verification-key _                         Proof|Signature|Both|Either|None
  --set-voting-for _                               Proof|Signature|Both|Either|None
  --snapp-account-key KEYFILE                      Private key file to create a
                                                   new snapp account
  [--debug]                                        Debug mode, generates
                                                   transaction snark
  [--fee FEE]                                      Amount you are willing to pay
                                                   to process the transaction
                                                   (default: 1) (minimum: 0.003)
  [--memo STRING]                                  Memo accompanying the
                                                   transaction
  [-help]                                          print this help text and exit
                                                   (alias: -?)

```

For example: To change the permission required to edit permissions from Signature to Proof

```shell
$mina-snapp-test-transaction update-permissions --fee-payer-key ..my-fee-payer --nonce 4 --snapp-account-key my-snapp-key --current-auth signature --edit-stake Proof --receive None --set-permissions Proof --set-delegate Signature --set-verification-key Signature --set-snapp-uri Signature --set-sequence-state Proof --set-token-symbol Signature --send Signature --increment-nonce Signature --set-voting-for Signature
```

```
mutation MyMutation {
  __typename
  sendSnapp(input: {
    feePayer:{data:{body:{publicKey:"B62qpfgnUm7zVqi8MJHNB2m37rtgMNDbFNhC2DpMmmVpQt8x6gKv9Ww",
        update:{appState:[null,
            null,
            null,
            null,
            null,
            null,
            null,
            null],
          delegate:null,
          verificationKey:null,
          permissions:null,
          snappUri:null,
          tokenSymbol:null,
          timing:null,
          votingFor:null},
        fee:"1000000000",
        events:[],
        sequenceEvents:[],
        callData:"0x0000000000000000000000000000000000000000000000000000000000000000",
        callDepth:0,
        protocolState:{snarkedLedgerHash:null,
          snarkedNextAvailableToken:null,
          timestamp:null,
          blockchainLength:null,
          minWindowDensity:null,
          lastVrfOutput:null,
          totalCurrency:null,
          globalSlotSinceHardFork:null,
          globalSlotSinceGenesis:null,
          stakingEpochData:{ledger:{hash:null,
              totalCurrency:null},
            seed:null,
            startCheckpoint:null,
            lockCheckpoint:null,
            epochLength:null},
          nextEpochData:{ledger:{hash:null,
              totalCurrency:null},
            seed:null,
            startCheckpoint:null,
            lockCheckpoint:null,
            epochLength:null}}},
      predicate:"4"},
    authorization:"7mXNK9nxCy71RyhLb5NjRSdYi3Lvhx5SCgjRmGKtSXNved7CWCwc3Vn5eHjTUvNrzyDuWSbb8f49Bjtr7KS3kxU59uhmpEyd"},
    otherParties:[{data:{body:{publicKey:"B62qmQDtbNTymWXdZAcp4JHjfhmWmuqHjwc6BamUEvD8KhFpMui2K1Z",
        update:{appState:[null,
            null,
            null,
            null,
            null,
            null,
            null,
            null],
          delegate:null,
          verificationKey:null,
          permissions:{stake:true,
            editState:Proof,
            send:Signature,
            receive:None,
            setDelegate:Signature,
            setPermissions:Proof,
            setVerificationKey:Signature,
            setSnappUri:Signature,
            editSequenceState:Proof,
            setTokenSymbol:Signature,
            incrementNonce:Signature,
            setVotingFor:Signature},
          snappUri:null,
          tokenSymbol:null,
          timing:null,
          votingFor:null},
        tokenId:"1",
        balanceChange:{magnitude:"0",
          sign:PLUS},
        incrementNonce:false,
        events:[],
        sequenceEvents:[],
        callData:"0x0000000000000000000000000000000000000000000000000000000000000000",
        callDepth:0,
        protocolState:{snarkedLedgerHash:null,
          snarkedNextAvailableToken:null,
          timestamp:null,
          blockchainLength:null,
          minWindowDensity:null,
          lastVrfOutput:null,
          totalCurrency:null,
          globalSlotSinceHardFork:null,
          globalSlotSinceGenesis:null,
          stakingEpochData:{ledger:{hash:null,
              totalCurrency:null},
            seed:null,
            startCheckpoint:null,
            lockCheckpoint:null,
            epochLength:null},
          nextEpochData:{ledger:{hash:null,
              totalCurrency:null},
            seed:null,
            startCheckpoint:null,
            lockCheckpoint:null,
            epochLength:null}},
        useFullCommitment:true},
      predicate:{account:null,
        nonce:null}},
    authorization:{signature:"7mXX6EYzQw2S3ZDUj4A8ECyuefJZLNRhGf6DLeinnbApfGVjYMkVZyzNGWnAaYqCuNDtNePL47G6EkrGQCcamgQw72rrR4qz"}}] })
}
  
```

Account state after the above transaction is included in a block

```
query MyQuery {
  account(publicKey: "B62qmQDtbNTymWXdZAcp4JHjfhmWmuqHjwc6BamUEvD8KhFpMui2K1Z") {
    permissions {
      editSequenceState
      editState
      incrementNonce
      receive
      send
      setDelegate
      setPermissions
      setSnappUri
      setTokenSymbol
      setVerificationKey
      setVotingFor
      stake
    }
  }
}

}
```

Result of the query

```json
{
  "data": {
    "account": {
      "permissions": {
        "editSequenceState": "Proof",
        "editState": "Proof",
        "incrementNonce": "Signature",
        "receive": "None",
        "send": "Signature",
        "setDelegate": "Signature",
        "setPermissions": "Proof",
        "setSnappUri": "Signature",
        "setTokenSymbol": "Signature",
        "setVerificationKey": "Signature",
        "setVotingFor": "Signature",
        "stake": true
      }
    }
  }
}
```
