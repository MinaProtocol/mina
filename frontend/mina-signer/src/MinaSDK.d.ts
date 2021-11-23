import { network, publicKey, keypair, privateKey, signed, payment, stakeDelegation, message } from "./TSTypes";
declare class Client {
    private network;
    constructor(options: {
        network: network;
    });
    /**
     * Generates a public/private keypair
     *
     * @returns A Mina keypair
     */
    genKeys(): keypair;
    /**
     * Verifies if a keypair is valid by checking if the public key can be derived from
     * the private key and additionally checking if we can use the private key to
     * sign a transaction. If the keypair is invalid, an exception is thrown.
     *
     * @param keypair - A keypair
     * @returns True if the `keypair` is a verifiable keypair, otherwise throw an exception
     */
    verifyKeypair(keypair: keypair): boolean;
    /**
     * Derives the public key of the corresponding private key
     *
     * @param privateKey - The private key used to get the corresponding public key
     * @returns A public key
     */
    derivePublicKey(privateKey: publicKey): publicKey;
    /**
     * Signs an arbitrary message
     *
     * @param message - An arbitrary string message to be signed
     * @param key- The keypair used to sign the message
     * @returns A signed message
     */
    signMessage(message: string, key: keypair): signed<message>;
    /**
     * Verifies that a signature matches a message.
     *
     * @param signedMessage - A signed message
     * @returns True if the `signedMessage` contains a valid signature matching
     * the message and publicKey.
     */
    verifyMessage(signedMessage: signed<message>): boolean;
    /**
     * Signs a payment transaction using a private key.
     *
     * This type of transaction allows a user to transfer funds from one account
     * to another over the network.
     *
     * @param payment - An object describing the payment
     * @param privateKey- The private key used to sign the transaction
     * @returns A signed payment transaction
     */
    signPayment(payment: payment, privateKey: privateKey): signed<payment>;
    /**
     * Verifies a signed payment.
     *
     * @param signedPayment - A signed payment transaction
     * @returns True if the `signed(payment)` is a verifiable payment
     */
    verifyPayment(signedPayment: signed<payment>): boolean;
    /**
     * Signs a stake delegation transaction using a private key.
     *
     * This type of transaction allows a user to delegate their
     * funds from one account to another for use in staking. The
     * account that is delegated to is then considered as having these
     * funds when determining whether it can produce a block in a given slot.
     *
     * @param stakeDelegation An object describing the stake delegation
     * @param privateKey The private key used to sign the transaction
     * @returns A signed stake delegation
     */
    signStakeDelegation(stakeDelegation: stakeDelegation, privateKey: privateKey): signed<stakeDelegation>;
    /**
     * Verifies a signed stake delegation.
     *
     * @param signedStakeDelegation - A signed stake delegation
     * @returns True if the `signed(stakeDelegation)` is a verifiable stake delegation
     */
    verifyStakeDelegation(signedStakeDelegation: signed<stakeDelegation>): boolean;
    /**
     * Compute the hash of a signed payment.
     *
     * @param signedPayment - A signed payment transaction
     * @returns A transaction hash
     */
    hashPayment(signedPayment: signed<payment>): string;
    /**
     * Compute the hash of a signed stake delegation.
     *
     * @param signedStakeDelegation - A signed stake delegation
     * @returns A transaction hash
     */
    hashStakeDelegation(signedStakeDelegation: signed<stakeDelegation>): string;
    /**
     * Converts a Rosetta signed transaction to a JSON string that is
     * compatible with GraphQL. The JSON string is a representation of
     * a `Signed_command` which is what our GraphQL expects.
     *
     * @param signedRosettaTxn - A signed Rosetta transaction
     * @returns A string that represents the JSON conversion of a signed Rosetta transaction`.
     */
    signedRosettaTransactionToSignedCommand(signedRosettaTxn: string): string;
    /**
     * Return the hex-encoded format of a valid public key. This will throw an exception if
     * the key is invalid or the conversion fails.
     *
     * @param publicKey - A valid public key
     * @returns A string that represents the hex encoding of a public key.
     */
    publicKeyToRaw(publicKey: string): string;
}
export = Client;
