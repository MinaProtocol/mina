#!/usr/bin/env node

/**
 * CLI utility for signing a Mina payment and broadcasting it via GraphQL.
 *
 * Responsibilities:
 *  - Parse and validate CLI input (private key, recipient, optional GraphQL URL and nonce)
 *  - Construct and sign a payment using `mina-signer`
 *  - Submit the signed payload to a Mina daemon and verify it reached the pool
 *
 * Usage:
 *    node test-signer.js <private_key> <recipient_address> [graphql_url] [nonce]
 */
import { PaymentService } from './payment-service.js';
import { GraphQLClient } from './graphql-client.js';
import { ValidationUtils } from './utils.js';
import { CONFIG, USAGE_INFO } from './config.js';

const DIVIDER = '────────────────────────────────────────';

const shortenKey = value => {
  if (!value) return 'n/a';
  const normalized = String(value);
  if (normalized.length <= 12) {
    return normalized;
  }
  return `${normalized.slice(0, 6)}...${normalized.slice(-6)}`;
};

const logger = {
  banner(title) {
    console.log(`\n✨ ${title}`);
    console.log(DIVIDER);
  },
  step(message) {
    console.log(`➡️  ${message}`);
  },
  info(message) {
    console.log(`ℹ️  ${message}`);
  },
  success(message) {
    console.log(`✅ ${message}`);
  },
  warn(message) {
    console.warn(`⚠️  ${message}`);
  },
  error(message) {
    console.error(`❌ ${message}`);
  },
  summary(items) {
    if (!items.length) {
      return;
    }
    console.log(`\n📋 Run Summary`);
    console.log(DIVIDER);
    items.forEach(({ label, success, detail }) => {
      const icon = success ? '✅' : '❌';
      const suffix = detail ? ` — ${detail}` : '';
      console.log(`${icon} ${label}${suffix}`);
    });
    console.log(DIVIDER);
  },
};

/**
 * Orchestrates the CLI flow by coordinating validation, signing, submission,
 * and follow-up checks against the daemon.
 */
class PaymentApp {
  constructor() {
    this.paymentService = new PaymentService();
  }

  /** Prints user-friendly guidance for invoking the CLI correctly. */
  displayUsage() {
    console.log(USAGE_INFO.message);
    console.log(USAGE_INFO.example);
    console.log(USAGE_INFO.defaultUrl);
  }

  /**
   * Ensures the caller provided required arguments before we attempt to sign.
   * Returns a normalized object that downstream logic can destructure safely.
   */
  validateAndParseArgs(args) {
    const validation = ValidationUtils.validateArgs(args);
    if (!validation.isValid) {
      console.error(validation.error);
      this.displayUsage();
      process.exit(1);
    }
    return ValidationUtils.parseArguments(args);
  }

  /**
   * Primary workflow:
   *  1. Gather CLI parameters and fall back to defaults when possible
   *  2. Construct and sign a payment payload
   *  3. Send the signed transaction and verify it enters the pool
   */
  async run() {
    const summary = [];
    const record = (label, success, detail) => summary.push({ label, success, detail });

    logger.banner('Mina Payment Signer');

    try {
      logger.step('Parsing command line arguments...');
      const args = process.argv.slice(2);
      const { privateKey, recipientAddress, url = CONFIG.DEFAULT_GRAPHQL_URL, nonce } =
        this.validateAndParseArgs(args);
      record('CLI arguments', true, `Recipient ${shortenKey(recipientAddress)} | Nonce ${nonce ?? 'auto'}`);

      logger.step('Creating unsigned payment payload...');
      const payment = this.paymentService.createPayment(privateKey, recipientAddress, { nonce });
      logger.info(`Sender public key: ${shortenKey(payment.from)}`);
      logger.info(`Amount: ${payment.amount} nanomina | Fee: ${payment.fee} nanomina`);
      record('Payment draft', true, `From ${shortenKey(payment.from)} → ${shortenKey(payment.to)} (nonce ${payment.nonce})`);

      logger.step('Signing payment...');
      const signedPayment = this.paymentService.signPayment(payment, privateKey);
      logger.info(`Signature field: ${shortenKey(signedPayment.signature?.field)} | scalar: ${shortenKey(signedPayment.signature?.scalar)}`);
      record('Signature', true, `Field ${shortenKey(signedPayment.signature?.field)}...`);

      const graphqlClient = new GraphQLClient(url);
      logger.step(`Submitting to GraphQL endpoint ${url}...`);
      // The GraphQL client returns the parsed JSON response from the daemon.
      const result = await graphqlClient.sendPayment(signedPayment);
      if (!result) {
        throw new Error('No response from GraphQL client.');
      }

      const paymentId = result?.data?.sendPayment?.payment?.id;
      if (!paymentId) {
        record('GraphQL submission', false, 'No payment id returned');
        throw new Error('GraphQL response did not include a payment id.');
      }
      record('GraphQL submission', true, `Payment id ${paymentId}`);
      logger.success(`GraphQL accepted payment id ${paymentId}.`);

      logger.step(`Verifying transaction ${paymentId} in pool...`);
      try {
        const isInPool = await graphqlClient.checkTransactionInPool(paymentId);
        if (isInPool) {
          logger.success(`Transaction ${paymentId} is currently in the pool.`);
          record('Pool status', true, 'Present in pool');
        } else {
          logger.warn(`Transaction ${paymentId} not found in the pool yet.`);
          record('Pool status', false, 'Not yet in pool');
        }
      } catch (poolError) {
        logger.error(`Pool check error: ${poolError.message}`);
        if (poolError.response) {
          logger.error(`Response: ${JSON.stringify(poolError.response)}`);
        }
        record('Pool status', false, poolError.message);
        throw poolError;
      }

      logger.success('🎉 All steps completed successfully.');
      record('Run status', true, 'All steps completed');
      logger.summary(summary);
    } catch (error) {
      logger.error(`Application error: ${error.message}`);
      if (error.response) {
        logger.error(`Response: ${JSON.stringify(error.response)}`);
      }
      record('Run status', false, error.message);
      logger.summary(summary);
      process.exit(1);
    }
  }
}

// Run the application
const app = new PaymentApp();
app.run();
