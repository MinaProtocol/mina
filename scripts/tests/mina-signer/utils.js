import { jsonToGraphQLQuery } from 'json-to-graphql-query';

/**
 * Utility helpers for constructing GraphQL payloads that the Mina GraphQL
 * endpoint accepts. These keep the string manipulation away from the core
 * payment workflow.
 */
export class GraphQLUtils {
  static createPaymentMutation(signedPayment) {
    const mutation = {
      mutation: {
        sendPayment: {
          __args: {
            input: signedPayment.data,
            signature: signedPayment.signature
          },
          payment: {
            id: true
          }
        }
      }
    };

    return jsonToGraphQLQuery(mutation, { pretty: true });
  }
}