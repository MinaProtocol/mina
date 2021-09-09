import * as SDK from "./CodaSDK";
export * from './CodaSDK';

export type signable = SDK.payment | SDK.stakeDelegation | string;

function hasCommonProperties(p: signable) {
  return p.hasOwnProperty("to") && p.hasOwnProperty("from") && p.hasOwnProperty("fee") && p.hasOwnProperty("nonce");
}

function isPayment(p: signable) : p is SDK.payment {
  return hasCommonProperties(p) && p.hasOwnProperty('amount');
}

function isStakeDelegation(p: signable): p is SDK.stakeDelegation {
    return hasCommonProperties(p) && !p.hasOwnProperty('amount');
}

/**
  * Signs an arbitrary signable payload using a private key.
  *
  * This is marked unsafe because it performs ad hoc checks on the
  * passed-in payload to determine which signing strategy to use.
  *
  * @param payload - An signable object or string
  * @param key - The keypair used to sign the transaction
  * @returns A signed payload
 */
export function unsafeSignAny(payload: string, key: SDK.keypair): SDK.signed<string>;
export function unsafeSignAny(payload: SDK.payment, key: SDK.keypair): SDK.signed<SDK.payment>;
export function unsafeSignAny(payload: SDK.stakeDelegation, key: SDK.keypair): SDK.signed<SDK.stakeDelegation>;
export function unsafeSignAny<T>(payload: signable, key: SDK.keypair): SDK.signed<signable> {
  if (typeof payload === 'string') { return SDK.signMessage(payload, key); }
  if (isPayment(payload)) { return SDK.signPayment(payload, key); }
  if (isStakeDelegation(payload)) { return SDK.signStakeDelegation(payload, key); }
  throw new Error(`Expected signable payload, got '${payload}'.`);
};