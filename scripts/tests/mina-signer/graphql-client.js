import { GraphQLUtils } from './utils.js';

/**
 * Minimal GraphQL transport layer responsible for broadcasting signed
 * payments to a Mina daemon and inspecting the transaction pool.
 */
export class GraphQLClient {
  constructor(url) {
    this.url = url;
  }

  /**
   * Posts a signed payment mutation to the configured GraphQL endpoint.
   * Surfaces detailed errors while preserving the structured response
   * the caller uses to confirm transaction submission.
   */
  async sendPayment(signedPayment) {
    const query = GraphQLUtils.createPaymentMutation(signedPayment);

    console.log('\n🚀 Sending payment via GraphQL');
    console.log(`🌐 Endpoint: ${this.url}`);
    console.log('📝 Mutation payload:');
    console.log(query);

    try {
      const response = await fetch(this.url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ operationName: null, query, variables: {} }),
      });

      return await this.handleResponse(response);
    } catch (error) {
      throw new Error(`Request error: ${error.message}`);
    }
  }

  /**
   * Normalizes the GraphQL response shape by either returning JSON data
   * or throwing a rich error that upstream callers can surface.
   */
  async handleResponse(response) {
    if (response.status === 200) {
      const rawBody = await response.text();

      let json;
      try {
        json = JSON.parse(rawBody);
      } catch (parseError) {
        throw new Error(
          `Unexpected JSON payload: ${parseError.message}. Raw response: ${rawBody}`
        );
      }

      if (json.errors?.length) {
        const combinedErrors = json.errors
          .map(error => error.message ?? JSON.stringify(error))
          .join(' | ');
        throw new Error(`GraphQL errors: ${combinedErrors}`);
      }

      console.log('📦 GraphQL response payload:');
      console.dir(json, { depth: null });
      return json;
    } else {
      const text = await response.text();
      throw new Error(`GraphQL error (${response.status}): ${text}`);
    }
  }

  /**
   * Queries the daemon's pooled commands and returns true when the given
   * transaction ID is currently staged for inclusion in a block.
   */
  async checkTransactionInPool(transactionId) {
    const query = `
      query MyQuery {
        pooledUserCommands {
          id
        }
      }
    `;

    try {
      const response = await fetch(this.url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          operationName: 'MyQuery', 
          query, 
          variables: {} 
        }),
      });

      const rawBody = await response.text();
      if (response.status !== 200) {
        throw new Error(`GraphQL error (${response.status}): ${rawBody}`);
      }

      let json;
      try {
        json = JSON.parse(rawBody);
      } catch (parseError) {
        throw new Error(
          `Unexpected JSON payload when checking pool: ${parseError.message}. Raw response: ${rawBody}`
        );
      }

      if (json.errors?.length) {
        const combinedErrors = json.errors
          .map(error => error.message ?? JSON.stringify(error))
          .join(' | ');
        throw new Error(`GraphQL errors while checking pool: ${combinedErrors}`);
      }

      const pooledCommands = json.data?.pooledUserCommands || [];
      return pooledCommands.some(command => command.id === transactionId);
    } catch (error) {
      console.error('Error checking transaction in pool:', error.message);
      throw error;
    }
  }

  /**
   * Convenience method that lists transaction IDs in the current pool.
   * Useful for manual debugging or exploratory scripts.
   */
  async getPooledUserCommands() {
    const query = `
      query MyQuery {
        pooledUserCommands {
          id
        }
      }
    `;

    try {
      const response = await fetch(this.url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          operationName: 'MyQuery', 
          query, 
          variables: {} 
        }),
      });

      const rawBody = await response.text();
      if (response.status !== 200) {
        throw new Error(`GraphQL error (${response.status}): ${rawBody}`);
      }

      let json;
      try {
        json = JSON.parse(rawBody);
      } catch (parseError) {
        throw new Error(
          `Unexpected JSON payload when fetching pooled commands: ${parseError.message}. Raw response: ${rawBody}`
        );
      }

      if (json.errors?.length) {
        const combinedErrors = json.errors
          .map(error => error.message ?? JSON.stringify(error))
          .join(' | ');
        throw new Error(`GraphQL errors while fetching pooled commands: ${combinedErrors}`);
      }

      console.log('📦 Pooled commands response payload:');
      console.dir(json, { depth: null });
      return json.data?.pooledUserCommands || [];
    } catch (error) {
      console.error('Error fetching pooled commands:', error.message);
      throw error;
    }
  }
}
