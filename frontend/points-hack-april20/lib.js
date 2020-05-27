// GraphQL stuff

const ws = require("ws");
const { gql } = require("apollo-server");
const { ApolloClient } = require("apollo-client");
const { ApolloLink } = require("apollo-link");
const { InMemoryCache } = require("apollo-cache-inmemory");
const { HttpLink } = require("apollo-link-http");
const { WebSocketLink } = require("apollo-link-ws");
const fetch = require("node-fetch");
const fs = require("fs");
const { tmpdir } = require("os");
const Path = require("path");

const CODA_GRAPHQL_HOST = process.env["CODA_GRAPHQL_HOST"] || "localhost";
const CODA_GRAPHQL_PORT = process.env["CODA_GRAPHQL_PORT"] || 3085;
const CODA_GRAPHQL_PATH = process.env["CODA_GRAPHQL_PATH"] || "/graphql";
const CODA_TESTNET_NAME = process.env["CODA_TESTNET_NAME"] || "unknown";

const API_KEY_SECRET = process.env["GOOGLE_CLOUD_STORAGE_API_KEY"];
if (!API_KEY_SECRET) {
  console.error(
    "Make sure you include GOOGLE_CLOUD_STORAGE_API_KEY env var with the contents of the storage private key json"
  );
  process.exit(1);
}

const json_file_path = Path.join(tmpdir(), "google_cloud_api_key.json");
fs.writeFileSync(json_file_path, API_KEY_SECRET);

const graphqlUriNoScheme =
  CODA_GRAPHQL_HOST + ":" + CODA_GRAPHQL_PORT + CODA_GRAPHQL_PATH;
const httpLink = new HttpLink({
  uri: "http://" + graphqlUriNoScheme,
  fetch: fetch,
});

const cache = new InMemoryCache();
const wsLink = new WebSocketLink({
  uri: "ws://" + graphqlUriNoScheme,
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

const storage = new Storage({
  projectId: "o1labs-192920",
  keyFilename: json_file_path,
});

function truncate(s, len) {
  return s.substring(0, Math.min(len, s.length));
}

function uploadFile(result) {
  const bucketName = "points-data-hack-april20";
  const filename =
    result.data && result.data.newBlock && result.data.newBlock.stateHash
      ? "block-success-" + truncate(result.data.newBlock.stateHash, 200) + ".json"
      : "block-error-" + Date.now() + ".json";

  const bucket = storage.bucket(bucketName);
  const file = bucket.file("v1/32b-" + CODA_TESTNET_NAME + "/" + filename);

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
      console.error("Failed uploading metric to google cloud", err);
    })
    .on("finish", function () {
      console.log(`Finished uploading ${filename} to ${bucketName}`);
    });
}

// Subscription

const SUBSCRIPTION = `
subscription Blocks {
  newBlock {
    creatorAccount {
      publicKey
    }
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
      coinbaseReceiverAccount {
        publicKey
      }
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
