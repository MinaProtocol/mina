import * as SDK from "./CodaSDK";
export * from './CodaSDK';
export declare type signable = SDK.payment | SDK.stakeDelegation | string;
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
export declare function unsafeSignAny(payload: string, key: SDK.keypair): SDK.signed<string>;
export declare function unsafeSignAny(payload: SDK.payment, key: SDK.keypair): SDK.signed<SDK.payment>;
export declare function unsafeSignAny(payload: SDK.stakeDelegation, key: SDK.keypair): SDK.signed<SDK.stakeDelegation>;
