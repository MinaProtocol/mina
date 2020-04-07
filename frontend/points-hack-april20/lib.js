// GraphQL stuff

const ws = require("ws");
const { gql } = require("apollo-server");
const { ApolloClient } = require("apollo-client");
const { ApolloLink } = require("apollo-link");
const { InMemoryCache } = require("apollo-cache-inmemory");
const { HttpLink } = require("apollo-link-http");
const { WebSocketLink } = require("apollo-link-ws");
const fetch = require("node-fetch");

const httpLink = new HttpLink({
  uri: "http://localhost:3085/graphql",
  fetch: fetch,
});

const cache = new InMemoryCache();
const wsLink = new WebSocketLink({
  uri: "ws://localhost:3085/graphql",
  options: { reconnect: true, connectionParams: null },
  webSocketImpl: ws,
});

const apolloClient = new ApolloClient({
  cache: cache,
  link: ApolloLink.split(
    (operation) => {
      const def = operation.query.definitions[0];
      return (
        def.kind == "OperationDefinition" && def.operation == "subscription"
      );
    },
    wsLink,
    httpLink
  ),
});

// Gcloud

const { Storage } = require("@google-cloud/storage");
const { Readable } = require("stream");

const storage = new Storage();

function uploadFile(result) {
  const bucketName = "points-data-hack-april20";
  const filename = "block-" + Date.now() + ".json";

  const bucket = storage.bucket(bucketName);
  const file = bucket.file("32qa/" + filename);

  const buffer = Buffer.from(JSON.stringify(result), "utf8");
  const readable = new Readable();
  readable._read = () => {};
  readable.push(buffer);
  readable.push(null);

  readable
    .pipe(
      file.createWriteStream({
        metadata: {
          contentType: "application/json",
          metadata: {
            cacheControl: "public, max-age=31536000",
          },
        },
      })
    )
    .on("error", function (err) {
      console.error("Failed uploading metric to google cloude", err);
    })
    .on("finish", function () {
      console.log(`Finished uploading ${filename} to ${bucketName}`);
    });
}

// Subscription

const SUBSCRIPTION = `
subscription Blocks {
  newBlock {
    protocolState {
      previousStateHash
      consensusState {
        blockHeight
        epoch
        epochCount
        hasAncestorInSameCheckpointWindow
        lastVrfOutput
        minWindowDensity
        nextEpochData {
          epochLength
          ledger {
            hash
            totalCurrency
          }
          lockCheckpoint
          seed
          startCheckpoint
        }
        slot
        totalCurrency
      }
      blockchainState {
        date
        snarkedLedgerHash
        stagedLedgerHash
      }
    }
    stateHash
    stateHashField
    snarkJobs {
      fee
      prover
      workIds
    }
    transactions {
      coinbase
      feeTransfer {
        fee
        recipient
      }
      userCommands {
        amount
        fee
        fromAccount {
          publicKey
        }
        id
        isDelegation
        memo
        nonce
        toAccount {
          publicKey
        }
      }
    }
  }
}`;

// listen on subscription and take results and upload them
console.log("Listening for new blocks...");
apolloClient
  .subscribe({
    query: gql(SUBSCRIPTION),
  })
  .subscribe({
    next(data) {
      console.log("Uploading result", data);
      uploadFile(data);
    },
    error(err) {
      console.log(`Finished with error: ${err}`);
    },
    complete() {
      console.log("Finished");
    },
  });
