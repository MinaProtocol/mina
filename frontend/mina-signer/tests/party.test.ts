import Client from "../src/MinaSigner";

let PARTY = `{
  "feePayer": {
    "data": {
      "body": {
        "publicKey": "B62qjPmFxcDN1WEwcar1Y1Wt6FduaJWtUNya91JGqHrdZLwrS3g2PNU",
        "update": {
          "appState": [null, null, null, null, null, null, null, null],
          "delegate": null,
          "verificationKey": null,
          "permissions": null,
          "snappUri": null,
          "tokenSymbol": null,
          "timing": null,
          "votingFor": null
        },
        "tokenId": null,
        "balanceChange": "0",
        "incrementNonce": null,
        "events": [],
        "sequenceEvents": [],
        "callData": "0",
        "callDepth": 0,
        "protocolState": {
          "snarkedLedgerHash": null,
          "snarkedNextAvailableToken": {
            "lower": "0",
            "upper": "18446744073709551615"
          },
          "timestamp": { "lower": "0", "upper": "-1" },
          "blockchainLength": { "lower": "0", "upper": "4294967295" },
          "minWindowDensity": { "lower": "0", "upper": "4294967295" },
          "lastVrfOutput": null,
          "totalCurrency": { "lower": "0", "upper": "18446744073709551615" },
          "globalSlotSinceHardFork": { "lower": "0", "upper": "4294967295" },
          "globalSlotSinceGenesis": { "lower": "0", "upper": "4294967295" },
          "stakingEpochData": {
            "ledger": {
              "hash": null,
              "totalCurrency": { "lower": "0", "upper": "18446744073709551615" }
            },
            "seed": null,
            "startCheckpoint": null,
            "lockCheckpoint": null,
            "epochLength": { "lower": "0", "upper": "4294967295" }
          },
          "nextEpochData": {
            "ledger": {
              "hash": null,
              "totalCurrency": { "lower": "0", "upper": "18446744073709551615" }
            },
            "seed": null,
            "startCheckpoint": null,
            "lockCheckpoint": null,
            "epochLength": { "lower": "0", "upper": "4294967295" }
          }
        },
        "useFullCommitment": null
      },
      "predicate": "0"
    },
    "authorization": "7mWxjLYgbJUkZNcGouvhVj5tJ8yu9hoexb9ntvPK8t5LHqzmrL6QJjjKtf5SgmxB4QWkDw7qoMMbbNGtHVpsbJHPyTy2EzRQ"
  },
  "otherParties": [
    {
      "data": {
        "body": {
          "publicKey": "B62qiuBjzNWbEtP86ETfNDmeza9j5WR9Yak8q2HegV5CDtXKQkXe7QP",
          "update": {
            "appState": [null, null, null, null, null, null, null, null],
            "delegate": null,
            "verificationKey": null,
            "permissions": null,
            "snappUri": null,
            "tokenSymbol": null,
            "timing": null,
            "votingFor": null
          },
          "tokenId": "1",
          "balanceChange": { "magnitude": "1000000", "sgn": "Negative" },
          "incrementNonce": false,
          "events": [],
          "sequenceEvents": [],
          "callData": "0",
          "callDepth": 0,
          "protocolState": {
            "snarkedLedgerHash": null,
            "snarkedNextAvailableToken": {
              "lower": "0",
              "upper": "18446744073709551615"
            },
            "timestamp": { "lower": "0", "upper": "-1" },
            "blockchainLength": { "lower": "0", "upper": "4294967295" },
            "minWindowDensity": { "lower": "0", "upper": "4294967295" },
            "lastVrfOutput": null,
            "totalCurrency": { "lower": "0", "upper": "18446744073709551615" },
            "globalSlotSinceHardFork": { "lower": "0", "upper": "4294967295" },
            "globalSlotSinceGenesis": { "lower": "0", "upper": "4294967295" },
            "stakingEpochData": {
              "ledger": {
                "hash": null,
                "totalCurrency": {
                  "lower": "0",
                  "upper": "18446744073709551615"
                }
              },
              "seed": null,
              "startCheckpoint": null,
              "lockCheckpoint": null,
              "epochLength": { "lower": "0", "upper": "4294967295" }
            },
            "nextEpochData": {
              "ledger": {
                "hash": null,
                "totalCurrency": {
                  "lower": "0",
                  "upper": "18446744073709551615"
                }
              },
              "seed": null,
              "startCheckpoint": null,
              "lockCheckpoint": null,
              "epochLength": { "lower": "0", "upper": "4294967295" }
            }
          },
          "useFullCommitment": true
        },
        "predicate": {
          "balance": null,
          "nonce": { "lower": "0", "upper": "0" },
          "receiptChainHash": null,
          "publicKey": null,
          "delegate": null,
          "state": [null, null, null, null, null, null, null, null],
          "sequenceState": null,
          "provedState": null
        }
      },
      "authorization": { "proof": null, "signature": null }
    },
    {
      "data": {
        "body": {
          "publicKey": "B62qqCWrtshCDcEFc1bwqK9Ddnoc6SDCJ8VGvkRS3cpYMPFfniwD8PS",
          "update": {
            "appState": ["1", null, null, null, null, null, null, null],
            "delegate": null,
            "verificationKey": null,
            "permissions": null,
            "snappUri": null,
            "tokenSymbol": null,
            "timing": null,
            "votingFor": null
          },
          "tokenId": "1",
          "balanceChange": { "magnitude": "1000000", "sgn": "Positive" },
          "incrementNonce": false,
          "events": [],
          "sequenceEvents": [],
          "callData": "0",
          "callDepth": 0,
          "protocolState": {
            "snarkedLedgerHash": null,
            "snarkedNextAvailableToken": {
              "lower": "0",
              "upper": "18446744073709551615"
            },
            "timestamp": { "lower": "0", "upper": "-1" },
            "blockchainLength": { "lower": "0", "upper": "4294967295" },
            "minWindowDensity": { "lower": "0", "upper": "4294967295" },
            "lastVrfOutput": null,
            "totalCurrency": { "lower": "0", "upper": "18446744073709551615" },
            "globalSlotSinceHardFork": { "lower": "0", "upper": "4294967295" },
            "globalSlotSinceGenesis": { "lower": "0", "upper": "4294967295" },
            "stakingEpochData": {
              "ledger": {
                "hash": null,
                "totalCurrency": {
                  "lower": "0",
                  "upper": "18446744073709551615"
                }
              },
              "seed": null,
              "startCheckpoint": null,
              "lockCheckpoint": null,
              "epochLength": { "lower": "0", "upper": "4294967295" }
            },
            "nextEpochData": {
              "ledger": {
                "hash": null,
                "totalCurrency": {
                  "lower": "0",
                  "upper": "18446744073709551615"
                }
              },
              "seed": null,
              "startCheckpoint": null,
              "lockCheckpoint": null,
              "epochLength": { "lower": "0", "upper": "4294967295" }
            }
          },
          "useFullCommitment": true
        },
        "predicate": {
          "balance": { "lower": "0", "upper": "18446744073709551615" },
          "nonce": { "lower": "0", "upper": "4294967295" },
          "receiptChainHash": null,
          "publicKey": null,
          "delegate": null,
          "state": [null, null, null, null, null, null, null, null],
          "sequenceState": null,
          "provedState": null
        }
      },
      "authorization": { "proof": null, "signature": null }
    }
  ],
  "memo": "E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH"
}`

describe("Party", () => {
    let client: Client;
    beforeAll(async () => {
      client = new Client({ network: "mainnet" });
    });
    it("tests party", () => {
      const party = client.signTransaction(PARTY)
      console.log("DEBUG", party)
      expect(true).toBeTruthy();
    });
});

