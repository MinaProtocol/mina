import { uint32 as $$uint32 } from './TSTypes';
import { uint64 as $$uint64 } from './TSTypes';
export declare type publicKey = string;
export declare type privateKey = string;
export declare type uint64 = $$uint64;
export declare type uint32 = $$uint32;
export declare type keypair = {
    readonly privateKey: privateKey;
    readonly publicKey: publicKey;
};
export declare type signature = {
    readonly field: string;
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
/**
  * Generates a public/private keypair
  */
export declare const genKeys: () => keypair;
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
