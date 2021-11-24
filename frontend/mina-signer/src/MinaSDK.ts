"use strict";

const JSOfOCaml_SDK = require("./client_sdk.bc.js");
const minaSDK = JSOfOCaml_SDK.minaSDK;

import {
  network,
  publicKey,
  keypair,
  privateKey,
  signed,
  payment,
  stakeDelegation,
  message,
} from "./TSTypes";

const defaultValidUntil = "4294967295";

class Client {
  private network: network;

  constructor(options: { network: network }) {
    if (options.network !== "mainnet" && options.network !== "testnet") {
      throw "Invalid Specified Network";
    }
    this.network = options.network;
  }

  /**
   * Generates a public/private keypair
   *
   * @returns A Mina keypair
   */
  public genKeys(): keypair {
    return minaSDK.genKeys();
  }

  /**
   * Verifies if a keypair is valid by checking if the public key can be derived from
   * the private key and additionally checking if we can use the private key to
   * sign a transaction. If the keypair is invalid, an exception is thrown.
   *
   * @param keypair - A keypair
   * @returns True if the `keypair` is a verifiable keypair, otherwise throw an exception
   */
  public verifyKeypair(keypair: keypair): boolean {
    return minaSDK.validKeypair(keypair);
  }

  /**
   * Derives the public key of the corresponding private key
   *
   * @param privateKey - The private key used to get the corresponding public key
   * @returns A public key
   */
  public derivePublicKey(privateKey: publicKey): publicKey {
    return minaSDK.publicKeyOfPrivateKey(privateKey);
  }

  /**
   * Signs an arbitrary message
   *
   * @param message - An arbitrary string message to be signed
   * @param key- The keypair used to sign the message
   * @returns A signed message
   */
  public signMessage(message: string, key: keypair): signed<message> {
    return {
      signature: minaSDK.signString(this.network, key.privateKey, message),
      data: {
        publicKey: key.publicKey,
        message,
      },
    };
  }

  /**
   * Verifies that a signature matches a message.
   *
   * @param signedMessage - A signed message
   * @returns True if the `signedMessage` contains a valid signature matching
   * the message and publicKey.
   */
  public verifyMessage(signedMessage: signed<message>): boolean {
    return minaSDK.verifyStringSignature(
      this.network,
      signedMessage.signature,
      signedMessage.data.publicKey,
      signedMessage.data
    );
  }

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
  public signPayment(
    payment: payment,
    privateKey: privateKey
  ): signed<payment> {
    const memo = payment.memo ?? "";
    const fee = String(payment.fee);
    const nonce = String(payment.nonce);
    const amount = String(payment.amount);
    const validUntil = String(
      payment.validUntil ? payment.validUntil : defaultValidUntil
    );
    return {
      signature: minaSDK.signPayment(this.network, privateKey, {
        common: {
          fee: fee,
          feePayer: payment.from,
          nonce: nonce,
          validUntil: validUntil,
          memo: memo,
        },
        paymentPayload: {
          source: payment.from,
          receiver: payment.to,
          amount: amount,
        },
      }).signature,
      data: {
        to: payment.to,
        from: payment.from,
        fee: fee,
        amount: amount,
        nonce: nonce,
        memo: memo,
        validUntil: validUntil,
      },
    };
  }

  /**
   * Verifies a signed payment.
   *
   * @param signedPayment - A signed payment transaction
   * @returns True if the `signed(payment)` is a verifiable payment
   */
  public verifyPayment(signedPayment: signed<payment>): boolean {
    const payload = signedPayment.data;
    const memo = payload.memo ?? "";
    const fee = String(payload.fee);
    const amount = String(payload.amount);
    const nonce = String(payload.nonce);
    const validUntil = String(
      payload.validUntil ? payload.validUntil : defaultValidUntil
    );
    return minaSDK.verifyPaymentSignature(this.network, {
      sender: signedPayment.data.from,
      signature: signedPayment.signature,
      payment: {
        common: {
          fee: fee,
          feePayer: payload.from,
          nonce: nonce,
          validUntil: validUntil,
          memo: memo,
        },
        paymentPayload: {
          source: payload.from,
          receiver: payload.to,
          amount: amount,
        },
      },
    });
  }

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
  public signStakeDelegation(
    stakeDelegation: stakeDelegation,
    privateKey: privateKey
  ): signed<stakeDelegation> {
    const memo = stakeDelegation.memo ?? "";
    const fee = String(stakeDelegation.fee);
    const nonce = String(stakeDelegation.nonce);
    const validUntil = String(
      stakeDelegation.validUntil
        ? stakeDelegation.validUntil
        : defaultValidUntil
    );
    return {
      signature: minaSDK.signStakeDelegation(this.network, privateKey, {
        common: {
          fee: fee,
          feePayer: stakeDelegation.from,
          nonce: nonce,
          validUntil: validUntil,
          memo: memo,
        },
        delegationPayload: {
          newDelegate: stakeDelegation.to,
          delegator: stakeDelegation.from,
        },
      }).signature,
      data: {
        to: stakeDelegation.to,
        from: stakeDelegation.from,
        fee: fee,
        nonce: nonce,
        memo: memo,
        validUntil: validUntil,
      },
    };
  }

  /**
   * Verifies a signed stake delegation.
   *
   * @param signedStakeDelegation - A signed stake delegation
   * @returns True if the `signed(stakeDelegation)` is a verifiable stake delegation
   */
  public verifyStakeDelegation(
    signedStakeDelegation: signed<stakeDelegation>
  ): boolean {
    const payload = signedStakeDelegation.data;
    const memo = payload.memo ?? "";
    const fee = String(payload.fee);
    const nonce = String(payload.nonce);
    const validUntil = String(
      payload.validUntil ? payload.validUntil : defaultValidUntil
    );
    return minaSDK.verifyStakeDelegationSignature(this.network, {
      sender: signedStakeDelegation.data.from,
      signature: signedStakeDelegation.signature,
      stakeDelegation: {
        common: {
          fee: fee,
          feePayer: payload.from,
          nonce: nonce,
          validUntil: validUntil,
          memo: memo,
        },
        delegationPayload: {
          newDelegate: payload.to,
          delegator: payload.from,
        },
      },
    });
  }

  /**
   * Compute the hash of a signed payment.
   *
   * @param signedPayment - A signed payment transaction
   * @returns A transaction hash
   */
  public hashPayment(signedPayment: signed<payment>): string {
    const payload = signedPayment.data;
    const memo = payload.memo ?? "";
    const fee = String(payload.fee);
    const amount = String(payload.amount);
    const nonce = String(payload.nonce);
    const validUntil = String(
      payload.validUntil ? payload.validUntil : defaultValidUntil
    );
    return minaSDK.hashPayment({
      sender: signedPayment.data.from,
      signature: signedPayment.signature,
      payment: {
        common: {
          fee: fee,
          feePayer: payload.from,
          nonce: nonce,
          validUntil: validUntil,
          memo: memo,
        },
        paymentPayload: {
          source: payload.from,
          receiver: payload.to,
          amount: amount,
        },
      },
    });
  }

  /**
   * Compute the hash of a signed stake delegation.
   *
   * @param signedStakeDelegation - A signed stake delegation
   * @returns A transaction hash
   */
  public hashStakeDelegation(
    signedStakeDelegation: signed<stakeDelegation>
  ): string {
    const payload = signedStakeDelegation.data;
    const memo = payload.memo ?? "";
    const fee = String(payload.fee);
    const nonce = String(payload.nonce);
    const validUntil = String(
      payload.validUntil ? payload.validUntil : defaultValidUntil
    );
    return minaSDK.hashStakeDelegation({
      sender: signedStakeDelegation.data.from,
      signature: signedStakeDelegation.signature,
      stakeDelegation: {
        common: {
          fee: fee,
          feePayer: payload.from,
          nonce: nonce,
          validUntil: validUntil,
          memo: memo,
        },
        delegationPayload: {
          newDelegate: payload.to,
          delegator: payload.from,
        },
      },
    });
  }

  /**
   * Converts a Rosetta signed transaction to a JSON string that is
   * compatible with GraphQL. The JSON string is a representation of
   * a `Signed_command` which is what our GraphQL expects.
   *
   * @param signedRosettaTxn - A signed Rosetta transaction
   * @returns A string that represents the JSON conversion of a signed Rosetta transaction`.
   */
  public signedRosettaTransactionToSignedCommand(
    signedRosettaTxn: string
  ): string {
    return minaSDK.signedRosettaTransactionToSignedCommand(signedRosettaTxn);
  }

  /**
   * Return the hex-encoded format of a valid public key. This will throw an exception if
   * the key is invalid or the conversion fails.
   *
   * @param publicKey - A valid public key
   * @returns A string that represents the hex encoding of a public key.
   */
  public publicKeyToRaw(publicKey: string): string {
    return minaSDK.rawPublicKeyOfPublicKey(publicKey);
  }
}

export = Client;
