const assert = require('assert');
const crypto = require('crypto');
const HTTPError = require('./httpError');

/**
 * Generate a signature for the provided payload.
 *
 * The secret must be available as an environment variable, GITHUB_SECRET.
 * Returns a string such as 'sha1=5d6466b80ce43f67026d652ad53cf3a68a4fafe6'.
 *
 * @param {String|Buffer} payload The payload to sign.
 */
exports.sign = (payload) => {
  const secret = process.env.GITHUB_SECRET;
  assert(secret, 'No secret');
  return `sha1=${crypto.createHmac('sha1', secret).update(payload).digest('hex')}`;
};

function verify(signature, body) {
  const payload = JSON.stringify(body);
  const payloadSignature = exports.sign(payload);
  if (signature.length === payloadSignature.length
    && crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(payloadSignature))) {
    return true;
  }
  console.info(`Provided signature (${signature}) did not match payload signature (${payloadSignature})`);
  throw new HTTPError(403, 'X-Hub-Signature mis-match');
}

/**
 * Verify that the webhook request came from GitHub.
 *
 * @param {object} headers The headers of the request.
 * @param {object} body The body of the request.
 */
exports.validateWebhook = ({ headers = null, body = null } = {}) => {
  if (!headers) throw new HTTPError(400);
  if (!body) throw new HTTPError(400);
  if (!headers['x-hub-signature']) throw new HTTPError(400, 'Must provide X-Hub-Signature header');
  if (!headers['x-github-event']) throw new HTTPError(400, 'Must provide X-GitHub-Event header');
  if (!headers['x-github-delivery']) throw new HTTPError(400, 'Must provide X-GitHub-Delivery header');
  console.info(`X-GitHub-Delivery: ${headers['x-github-delivery']}`);
  return verify(headers['x-hub-signature'], body);
};

/**
 * Get the branch name from the Git ref
 * Given a ref like "refs/head/branch-name", returns "branch-name", else null.
 *
 * @param {string} ref The full Git ref that was pushed, e.g. "refs/heads/master"
 */
exports.getBranchName = (ref) => {
  const regex = /refs\/heads\/(.+)/;
  const found = ref && ref.match(regex);
  if (found) {
    return found[1];
  }
  return null;
};
