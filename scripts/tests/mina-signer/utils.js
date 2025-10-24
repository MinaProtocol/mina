/**
 * Utility helpers for constructing GraphQL payloads that the Mina GraphQL
 * endpoint accepts. These keep the string manipulation away from the core
 * payment workflow.
 */
export class GraphQLUtils {
  static objectToGraphqlQuery(obj) {
    const json = JSON.stringify(obj, null, 2);
    return json.replace(/\"(\S+)\"\s*:/gm, '$1:');
  }

  static createPaymentMutation(signedPayment) {
    return `mutation {
      sendPayment(
        input: ${this.objectToGraphqlQuery(signedPayment.data)},
        signature: ${this.objectToGraphqlQuery(signedPayment.signature)}
      ) {
        payment { id }
      }
    }`;
  }
}

/**
 * Simple CLI argument validation and parsing helpers so that the main
 * entry point can focus on business logic.
 */
export class ValidationUtils {
  static validateArgs(args) {
    if (args.length < 2) {
      return { isValid: false, error: 'Insufficient arguments' };
    }

    const [, , thirdArg, fourthArg] = args;
    const nonceCandidate = fourthArg ?? (!thirdArg?.startsWith('http') ? thirdArg : undefined);

    if (nonceCandidate !== undefined) {
      const parsedNonce = Number(nonceCandidate);
      if (!Number.isInteger(parsedNonce) || parsedNonce < 0) {
        return { isValid: false, error: 'Nonce must be a non-negative integer' };
      }
    }

    return { isValid: true };
  }

  static parseArguments(args) {
    const [privateKey, recipientAddress, thirdArg, fourthArg] = args;

    let url;
    let rawNonce;

    if (thirdArg) {
      if (thirdArg.startsWith('http')) {
        url = thirdArg;
        rawNonce = fourthArg;
      } else {
        rawNonce = thirdArg;
        url = fourthArg;
      }
    } else {
      url = undefined;
      rawNonce = undefined;
    }

    const nonce = rawNonce !== undefined ? Number(rawNonce) : undefined;

    return { privateKey, recipientAddress, url, nonce };
  }
}
