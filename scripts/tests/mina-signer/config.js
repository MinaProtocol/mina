/**
 * Centralized configuration for Mina payment signing.
 * Keeps network defaults and unit conversion helpers in one place so
 * the rest of the code can remain declarative.
 */
export const CONFIG = {
  NETWORK: 'testnet',
  DEFAULT_GRAPHQL_URL: 'http://localhost:3085/graphql',
  MINA_UNITS: {
    ONE_MINA: 1000000000,
    DEFAULT_AMOUNT_MULTIPLIER: 150,
    DEFAULT_FEE_MULTIPLIER: 1
  }
};

/**
 * Human-friendly CLI usage text that `test-signer.js` displays when
 * the caller provides incomplete arguments.
 */
export const USAGE_INFO = {
  message: 'Usage: node test-signer.js <private_key> <recipient_address> [graphql_url] [nonce]',
  example: 'Example: node test-signer.js <private_key> <recipient_address> http://localhost:3085/graphql 3',
  defaultUrl: `Default GraphQL URL: ${CONFIG.DEFAULT_GRAPHQL_URL}`
};
