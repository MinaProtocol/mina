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
 *    node test-signer.js --private-key <key> --recipient <address> [--url <graphql_url>] [--nonce <nonce>]
 */
import { Command } from 'commander';
import { GraphQLClient } from './graphql-client.js';
import { CONFIG } from './config.js';
import Client from 'mina-signer';

const DIVIDER = '────────────────────────────────────────';

const showKey = value => {
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
    this.program = new Command();
    this.setupCLI();
  }

  /** Configure CLI options and arguments using commander */
  setupCLI() {
    this.program
      .name('mina-test-signer')
      .description('CLI utility for signing and broadcasting Mina payments')
      .version('1.0.0')
      .requiredOption('-k, --private-key <key>', 'Private key for signing the payment')
      .requiredOption('-r, --recipient <address>', 'Recipient public key address')
      .option('-u, --url <url>', 'GraphQL endpoint URL', CONFIG.DEFAULT_GRAPHQL_URL)
      .option('-n, --nonce <nonce>', 'Transaction nonce (optional, will be fetched if not provided)', parseInt)
      .parse();
  }

  /** Prints user-friendly guidance for invoking the CLI correctly. */
  displayUsage() {
    this.program.help();
  }

  /**
   * Get parsed and validated CLI options from commander
   */
  validateAndParseArgs() {
    const options = this.program.opts();
    return {
      privateKey: options.privateKey,
      recipientAddress: options.recipient,
      url: options.url,
      nonce: options.nonce
    };
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
      const { privateKey, recipientAddress, url, nonce } = this.validateAndParseArgs();
      record('CLI arguments', true, `Recipient ${showKey(recipientAddress)} | Nonce ${nonce ?? 'auto'}`);

      logger.step('Creating unsigned payment payload...');
      const client = new Client({ network: CONFIG.NETWORK });
      const publicKey = client.derivePublicKey(privateKey);
      const { ONE_MINA, DEFAULT_FEE_MULTIPLIER } = CONFIG.MINA_UNITS;

      const payment = {
        from: publicKey,
        to: recipientAddress,
        amount: ONE_MINA,
        nonce,
        fee: ONE_MINA * DEFAULT_FEE_MULTIPLIER,
      };

      logger.info(`Sender public key: ${showKey(payment.from)}`);
      logger.info(`Amount: ${payment.amount} nanomina | Fee: ${payment.fee} nanomina`);
      record('Payment draft', true, `From ${showKey(payment.from)} → ${showKey(payment.to)} (nonce ${payment.nonce})`);

      logger.step('Signing payment...');
      const signedPayment = client.signPayment(payment, privateKey);
      logger.info(`Signature field: ${showKey(signedPayment.signature?.field)} | scalar: ${showKey(signedPayment.signature?.scalar)}`);
      record('Signature', true, `Field ${showKey(signedPayment.signature?.field)}...`);

      const graphqlClient = new GraphQLClient(url);
      logger.step(`Submitting to GraphQL endpoint ${url}...`);
      // The GraphQL client returns the parsed JSON response from the daemon.
      const result = await graphqlClient.sendPayment(signedPayment);

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
        record('Pool status', false, poolError.message);
        throw poolError;
      }

      logger.success('🎉 All steps completed successfully.');
      record('Run status', true, 'All steps completed');
      logger.summary(summary);
    } catch (error) {
      logger.error(`Application error: ${error.message}`);
      record('Run status', false, error.message);
      logger.summary(summary);
      process.exit(1);
    }
  }
}

// Run the application
const app = new PaymentApp();
app.run();
