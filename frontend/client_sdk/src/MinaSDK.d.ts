import type { Undefined_t as Js_Undefined_t } from './Js.gen';
import type { authRequired as $$authRequired } from './TSTypes';
import type { field as $$field } from './TSTypes';
import type { int64 as $$int64 } from './TSTypes';
import type { list } from './ReasonPervasives.gen';
import type { sign as $$sign } from './TSTypes';
import type { uint32 as $$uint32 } from './TSTypes';
import type { uint64 as $$uint64 } from './TSTypes';
export declare type publicKey = string;
export declare type privateKey = string;
export declare type proof = string;
export declare type uint64 = $$uint64;
export declare type uint32 = $$uint32;
export declare type int64 = $$int64;
export declare type field = $$field;
export declare type keypair = {
    readonly privateKey: privateKey;
    readonly publicKey: publicKey;
};
export declare type signature = {
    readonly field: field;
    readonly scalar: string;
};
export declare type signed<signable> = {
    readonly publicKey: publicKey;
    readonly signature: signature;
    readonly payload: signable;
};
export declare type stakeDelegation = {
    readonly to: publicKey;
    readonly from: publicKey;
    readonly fee: uint64;
    readonly nonce: uint32;
    readonly memo?: string;
    readonly validUntil?: uint32;
};
export declare type payment = {
    readonly to: publicKey;
    readonly from: publicKey;
    readonly fee: uint64;
    readonly amount: uint64;
    readonly nonce: uint32;
    readonly memo?: string;
    readonly validUntil?: uint32;
};
export declare type sign = $$sign;
export declare type authRequired = $$authRequired;
export declare type Party_timing = {
    readonly initialMinimumBalance: string;
    readonly cliffTime: string;
    readonly cliffAmount: string;
    readonly vestingPeriod: string;
    readonly vestingIncrement: string;
};
export declare type Party_permissions = {
    readonly stake: boolean;
    readonly editState: authRequired;
    readonly send: authRequired;
    readonly receive: authRequired;
    readonly setDelegate: authRequired;
    readonly setPermissions: authRequired;
    readonly setVerificationKey: authRequired;
    readonly setSnappUri: authRequired;
    readonly editRollupState: authRequired;
    readonly setTokenSymbol: authRequired;
};
export declare type Party_verificationKeyWithHash = {
    readonly verificationKey: string;
    readonly hash: string;
};
export declare type Party_delta = {
    readonly sign: sign;
    readonly magnitude: uint64;
};
export declare type Party_update = {
    readonly appState: list<Js_Undefined_t<field>>;
    readonly delegate: Js_Undefined_t<publicKey>;
    readonly verificationKey: Js_Undefined_t<Party_verificationKeyWithHash>;
    readonly permissions: Js_Undefined_t<Party_permissions>;
    readonly snappUri: Js_Undefined_t<string>;
    readonly tokenSymbol: Js_Undefined_t<string>;
    readonly timing: Js_Undefined_t<Party_timing>;
};
export declare type Party_body = {
    readonly publicKey: publicKey;
    readonly update: Party_update;
    readonly tokenId: [number, number];
    readonly delta: Party_delta;
    readonly events: list<list<string>>;
    readonly rollupEvents: list<list<string>>;
    readonly callData: string;
};
export declare type Party_interval<a> = {
    readonly lower: a;
    readonly upper: a;
};
export declare type Party_state = {
    readonly elements: list<Js_Undefined_t<field>>;
};
export declare type Party_account = {
    readonly balance: Js_Undefined_t<Party_interval<uint64>>;
    readonly nonce: Js_Undefined_t<Party_interval<uint32>>;
    readonly receipt_chain_hash: Js_Undefined_t<string>;
    readonly publicKey: Js_Undefined_t<publicKey>;
    readonly delegate: Js_Undefined_t<publicKey>;
    readonly state: Party_state;
    readonly rollupState: Js_Undefined_t<field>;
    readonly provedState: Js_Undefined_t<boolean>;
};
export declare type Party_predicate = {
    readonly account: Js_Undefined_t<Party_account>;
    readonly nonce: Js_Undefined_t<uint32>;
};
export declare type Party_predicated<predicate> = {
    readonly body: Party_body;
    readonly predicate: predicate;
};
export declare type Party_member<auth, predicate> = {
    readonly authorization: auth;
    readonly data: Party_predicated<predicate>;
};
export declare type Party_proof_or_signature = {
    readonly proof: Js_Undefined_t<proof>;
    readonly signature: Js_Undefined_t<signature>;
};
export declare type Party_protocolState = {
    readonly snarkedLedgerHash: Js_Undefined_t<string>;
    readonly snarkedNextAvailableToken: Js_Undefined_t<[number, number]>;
    readonly snarkedLedgerHash: Js_Undefined_t<string>;
    readonly timestamp: Js_Undefined_t<uint64>;
    readonly blockchainLength: Js_Undefined_t<uint32>;
    readonly minWindowDensity: Js_Undefined_t<uint32>;
    readonly lastVrfOutput: Js_Undefined_t<string>;
    readonly totalCurrency: Js_Undefined_t<uint64>;
    readonly globalSlotSinceHardFork: Js_Undefined_t<string>;
    readonly globalSlotSinceGenesis: Js_Undefined_t<string>;
    readonly stakingEpochData: Js_Undefined_t<string>;
    readonly nextEpochData: Js_Undefined_t<string>;
};
export declare type Party_t = {
    readonly feePayer: Party_member<signature, uint32>;
    readonly otherParties: Party_member<Party_proof_or_signature, Party_predicate>[];
    readonly protocolState: Party_protocolState;
};
/**
  * Generates a public/private keypair
  */
export declare const genKeys: () => keypair;
/**
  * Derives the public key of the corresponding private key
  *
  * @param privateKey - The private key used to get the corresponding public key
  * @returns A public key
  */
export declare const derivePublicKey: (privateKey: privateKey) => publicKey;
/**
  * Verifies if a keypair is valid by checking if the public key can be derived from
  * the private key and additionally checking if we can use the private key to
  * sign a transaction. If the keypair is invalid, an exception is thrown.
  *
  * @param keypair - A keypair
  * @returns True if the `keypair` is a verifiable keypair, otherwise throw an exception
   */
export declare const verifyKeypair: (keypair: keypair) => boolean;
/**
  * Signs an arbitrary message
  *
  * @param key - The keypair used to sign the message
  * @param message - An arbitrary string message to be signed
  * @returns A signed message
  */
export declare const signMessage: (message: string, key: keypair) => signed<string>;
/**
  * Verifies that a signature matches a message.
  *
  * @param signedMessage - A signed message
  * @returns True if the `signedMessage` contains a valid signature matching
  * the message and publicKey.
  */
export declare const verifyMessage: (signedMessage: signed<string>) => boolean;
/**
  * Signs a payment transaction using a private key.
  *
  * This type of transaction allows a user to transfer funds from one account
  * to another over the network.
  *
  * @param payment - An object describing the payment
  * @param key - The keypair used to sign the transaction
  * @returns A signed payment transaction
  */
export declare const signPayment: (payment: payment, key: keypair) => signed<payment>;
/**
  * Signs a stake delegation transaction using a private key.
  *
  * This type of transaction allows a user to delegate their
  * funds from one account to another for use in staking. The
  * account that is delegated to is then considered as having these
  * funds when determining whether it can produce a block in a given slot.
  *
  * @param stakeDelegation - An object describing the stake delegation
  * @param key - The keypair used to sign the transaction
  * @returns A signed stake delegation
  */
export declare const signStakeDelegation: (stakeDelegation: stakeDelegation, key: keypair) => signed<stakeDelegation>;
/**
  * Verifies a signed payment.
  *
  * @param signedPayment - A signed payment transaction
  * @returns True if the `signed(payment)` is a verifiable payment
   */
export declare const verifyPaymentSignature: (signedPayment: signed<payment>) => boolean;
/**
  * Verifies a signed stake delegation.
  *
  * @param signedStakeDelegation - A signed stake delegation
  * @returns True if the `signed(stakeDelegation)` is a verifiable stake delegation
   */
export declare const verifyStakeDelegationSignature: (signedStakeDelegation: signed<stakeDelegation>) => boolean;
/**
  * Compute the hash of a signed payment.
  *
  * @param signedPayment - A signed payment transaction
  * @returns A transaction hash
   */
export declare const hashPayment: (signedPayment: signed<payment>) => string;
/**
  * Compute the hash of a signed stake delegation.
  *
  * @param signedStakeDelegation - A signed stake delegation
  * @returns A transaction hash
   */
export declare const hashStakeDelegation: (signedStakeDelegation: signed<stakeDelegation>) => string;
/**
  * Converts a Rosetta signed transaction to a JSON string that is
  * compatible with GraphQL. The JSON string is a representation of
  * a `Signed_command` which is what our GraphQL expects.
  *
  * @param signedRosettaTxn - A signed Rosetta transaction
  * @returns A string that represents the JSON conversion of a signed Rosetta transaction`.
   */
export declare const signedRosettaTransactionToSignedCommand: (signedRosettaTxn: string) => string;
/**
  * Return the hex-encoded format of a valid public key. This will throw an exception if
  * the key is invalid or the conversion fails.
  *
  * @param publicKey - A valid public key
  * @returns A string that represents the hex encoding of a public key.
   */
export declare const publicKeyToRaw: (publicKey: string) => string;
