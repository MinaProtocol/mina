export declare type publicKey = string;
export declare type privateKey = string;
export declare type globalSlot = number;
export declare type uint64 = string;
export declare type key = {
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
    readonly nonce: number;
    readonly memo?: string;
    readonly validUntil: globalSlot;
};
export declare type payment = {
    readonly to: publicKey;
    readonly from: publicKey;
    readonly fee: uint64;
    readonly amount: uint64;
    readonly nonce: number;
    readonly memo?: string;
    readonly validUntil: globalSlot;
};
/**
  * Generates a public/private keypair
  */
export declare const genKeys: () => key;
/**
  * Signs an arbitrary message
  *
  * @param key - The keypair used to sign the message
  * @param message - An arbitrary string message to be signed
  * @returns A signed message
  */
export declare const signMessage: (message: string, key: key) => signed<string>;
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
export declare const signPayment: (payment: payment, key: key) => signed<payment>;
/**
  * Signs a stake delegation transaction using a private key.
  *
  * This type of transaction allows a user to delegate their
  * funds from one account to another for use in staking. The
  * account that is delegated to is then considered as having these
  * funds when determininng whether it can produce a block in a given slot.
  *
  * @param stakeDelegation - An object describing the stake delegation
  * @param key - The keypair used to sign the transaction
  * @returns A signed stake delegation
  */
export declare const signStakeDelegation: (stakeDelegation: stakeDelegation, key: key) => signed<stakeDelegation>;
