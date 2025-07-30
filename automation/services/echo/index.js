const ws = require("ws");
const gql = require("graphql-tag");
const fetch = require("node-fetch");
const { split } = require("apollo-link");
const { HttpLink } = require("apollo-link-http");
const { ApolloClient } = require("apollo-client");
const { WebSocketLink } = require("apollo-link-ws");
const { InMemoryCache } = require("apollo-cache-inmemory");
const { getMainDefinition } = require("apollo-utilities");

const logger = require("./logger.js");

// Set up our GraphQL client

const {
  CODA_HOST = "localhost",
  CODA_PORT = 0xc0da,
  PUBLIC_KEY,
  FEE = 5
} = process.env;

const httpLink = new HttpLink({
  uri: `http://${CODA_HOST}:${CODA_PORT}/graphql`,
  fetch
});

const wsLink = new WebSocketLink({
  uri: `ws://${CODA_HOST}:${CODA_PORT}/graphql`,
  options: {
    reconnect: true
  },
  webSocketImpl: ws
});

const link = split(
  ({ query }) => {
    const definition = getMainDefinition(query);
    return (
      definition.kind === "OperationDefinition" &&
      definition.operation === "subscription"
    );
  },
  wsLink,
  httpLink
);

const cache = new InMemoryCache();

const client = new ApolloClient({ cache, link });

const processedBlocks = [];

// Queries

const walletsQuery = gql`
  query ownedWallets {
    ownedWallets {
      publicKey
    }
  }
`;

const addWalletMutation = gql`
  mutation addWallet {
    addWallet {
      publicKey
    }
  }
`;

const newBlockSubscription = gql`
  subscription newBlock($publicKey: PublicKey!) {
    newBlock(publicKey: $publicKey) {
      stateHash
      transactions {
        userCommands {
          isDelegation
          from
          to
          amount
          fee
        }
      }
    }
  }
`;

const sendPaymentMutation = gql`
  mutation sendPayment(
    $fee: UInt64!
    $amount: UInt64!
    $to: PublicKey!
    $from: PublicKey!
  ) {
    sendPayment(input: { amount: $amount, fee: $fee, to: $to, from: $from }) {
      payment {
        id
        from
        to
        nonce
        amount
        fee
      }
    }
  }
`;

// Handlers

const extractPublicKey = ({ data }) => {
  if (data.ownedWallets.length === 0) {
    logger.info("Node doesn't have any owned wallets. Creating a new one...");
    return client.mutate({ mutation: addWalletMutation }).then(({ data }) => {
      logger.info("Successfully created wallet.");
      return data.addWallet.publicKey;
    });
  } else if (!data.ownedWallets[0].publicKey) {
    throw Error("Invalid public key for first owned wallet.");
  }

  return data.ownedWallets[0].publicKey;
};

const reverseTransaction = txn =>
  client
    .mutate({
      mutation: sendPaymentMutation,
      variables: {
        fee: FEE,
        amount: txn.amount - FEE,
        to: txn.from,
        from: txn.to
      }
    })
    .then(({ data }) => {
      logger.info(
        `💸 Sent transaction to ${data.sendPayment.payment.to}`,
        data.sendPayment.payment
      );
    });

const handleBlock = ({ data }, publicKey) => {
  if (!data.newBlock.transactions) {
    return;
  }

  const { stateHash, transactions } = data.newBlock;

  if (processedBlocks.includes(stateHash)) {
    logger.warn(`⚠️ Already processed block ${stateHash}`);
    return;
  } else {
    const cacheSize = processedBlocks.push(stateHash);
    // Keep cache to 20 elements to prevent memory leak
    if (cacheSize > 20) processedBlocks.shift();
  }

  Promise.all(
    transactions.userCommands
      .filter(txn => txn.to === publicKey && txn.amount > FEE)
      .map(reverseTransaction)
  )
    .then(() => logger.info(`✅ Successfully processed block ${stateHash}`))
    .catch(logger.error);
};

const subscribeToBlocks = publicKey => {
  logger.info(`👂 Listening for transactions sent to ${publicKey}`);
  client
    .subscribe({
      query: newBlockSubscription,
      variables: { publicKey }
    })
    .forEach(block => handleBlock(block, publicKey))
    .catch(logger.error);
};

// Start listening

logger.info("Starting echo service...");

if (PUBLIC_KEY) {
  logger.info("Public key provided via PUBLIC_KEY.");
  subscribeToBlocks(PUBLIC_KEY);
} else {
  logger.info("No public key provided, looking for existing wallets...");
  client
    .query({ query: walletsQuery })
    .then(extractPublicKey)
    .then(subscribeToBlocks)
    .catch(logger.error);
}
