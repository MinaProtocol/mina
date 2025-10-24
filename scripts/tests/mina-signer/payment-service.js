import Client from 'mina-signer';
import { CONFIG } from './config.js';

/**
 * Thin wrapper around `mina-signer` that derives keys, builds payment
 * payloads with sensible defaults, and signs them for submission.
 */
export class PaymentService {
  constructor(network = CONFIG.NETWORK) {
    this.client = new Client({ network });
  }

  /**
   * Translates a private key into its corresponding public key, delegating
   * to the Mina signer library.
   */
  derivePublicKey(privateKey) {
    return this.client.derivePublicKey(privateKey);
  }

  /**
   * Drafts a payment with reasonable defaults for nonce, fee, and amount.
   * The caller can override the amount via an options object or by passing
   * a numeric multiplier (legacy behaviour), and can now set an explicit nonce.
   */
  createPayment(fromPrivateKey, toAddress, options = {}) {
    const publicKey = this.derivePublicKey(fromPrivateKey);
    const { ONE_MINA, DEFAULT_FEE_MULTIPLIER, DEFAULT_AMOUNT_MULTIPLIER } = CONFIG.MINA_UNITS;

    let amountMultiplier = DEFAULT_AMOUNT_MULTIPLIER;
    let nonce = 0;

    if (typeof options === 'number') {
      amountMultiplier = options;
    } else if (typeof options === 'object' && options !== null) {
      if (options.amountMultiplier !== undefined) {
        amountMultiplier = options.amountMultiplier;
      }
      if (options.nonce !== undefined) {
        nonce = options.nonce;
      }
    }

    return {
      from: publicKey,
      to: toAddress,
      amount: ONE_MINA * amountMultiplier,
      nonce,
      fee: ONE_MINA * DEFAULT_FEE_MULTIPLIER,
    };
  }

  /**
   * Signs a Mina payment object using the provided private key so it can
   * be broadcast via GraphQL.
   */
  signPayment(payment, privateKey) {
    return this.client.signPayment(payment, privateKey);
  }
}
