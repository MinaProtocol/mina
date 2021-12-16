"use strict";
const JSOfOCaml_SDK = require("./client_sdk.bc.js");
const minaSDK = JSOfOCaml_SDK.minaSDK;

import {
  Network,
  PublicKey,
  Keypair,
  PrivateKey,
  Signed,
  Payment,
  StakeDelegation,
  Message,
} from "./TSTypes";

const defaultValidUntil = "4294967295";

class Client {
  private network: Network;

  constructor(options: { network: Network }) {
    if (!options?.network) {
      throw "Invalid Specified Network";
    }
    const specifiedNetwork = options.network.toLowerCase();
    if (specifiedNetwork !== "mainnet" && specifiedNetwork !== "testnet") {
      throw "Invalid Specified Network";
    }
    this.network = specifiedNetwork;
  }

  /**
   * Generates a public/private key pair
   *
   * @returns A Mina key pair
   */
  public genKeys(): Keypair {
    return minaSDK.genKeys();
  }

  /**
   * Verifies if a key pair is valid by checking if the public key can be derived from
   * the private key and additionally checking if we can use the private key to
   * sign a transaction. If the key pair is invalid, an exception is thrown.
   *
   * @param keypair A key pair
   * @returns True if the `keypair` is a verifiable key pair, otherwise throw an exception
   */
  public verifyKeypair(keypair: Keypair): boolean {
    return minaSDK.validKeypair(keypair);
  }

  /**
   * Derives the public key of the corresponding private key
   *
   * @param privateKey The private key used to get the corresponding public key
   * @returns A public key
   */
  public derivePublicKey(privateKey: PrivateKey): PublicKey {
    return minaSDK.publicKeyOfPrivateKey(privateKey);
  }

  /**
   * Signs an arbitrary message
   *
   * @param message An arbitrary string message to be signed
   * @param key The key pair used to sign the message
   * @returns A signed message
   */
  public signMessage(message: string, key: Keypair): Signed<Message> {
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
   * @param signedMessage A signed message
   * @returns True if the `signedMessage` contains a valid signature matching
   * the message and publicKey.
   */
  public verifyMessage(signedMessage: Signed<Message>): boolean {
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
   * @param payment An object describing the payment
   * @param privateKey The private key used to sign the transaction
   * @returns A signed payment transaction
   */
  public signPayment(
    payment: Payment,
    privateKey: PrivateKey
  ): Signed<Payment> {
    const memo = payment.memo ?? "";
    const fee = String(payment.fee);
    const nonce = String(payment.nonce);
    const amount = String(payment.amount);
    const validUntil = String(payment.validUntil ?? defaultValidUntil);
    return {
      signature: minaSDK.signPayment(this.network, privateKey, {
        common: {
          fee,
          feePayer: payment.from,
          nonce,
          validUntil,
          memo,
        },
        paymentPayload: {
          source: payment.from,
          receiver: payment.to,
          amount,
        },
      }).signature,
      data: {
        to: payment.to,
        from: payment.from,
        fee,
        amount,
        nonce,
        memo,
        validUntil,
      },
    };
  }

  /**
   * Verifies a signed payment.
   *
   * @param signedPayment A signed payment transaction
   * @returns True if the `signed(payment)` is a verifiable payment
   */
  public verifyPayment(signedPayment: Signed<Payment>): boolean {
    const payload = signedPayment.data;
    const memo = payload.memo ?? "";
    const fee = String(payload.fee);
    const amount = String(payload.amount);
    const nonce = String(payload.nonce);
    const validUntil = String(payload.validUntil ?? defaultValidUntil);
    return minaSDK.verifyPaymentSignature(this.network, {
      sender: signedPayment.data.from,
      signature: signedPayment.signature,
      payment: {
        common: {
          fee,
          feePayer: payload.from,
          nonce,
          validUntil,
          memo,
        },
        paymentPayload: {
          source: payload.from,
          receiver: payload.to,
          amount,
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
    stakeDelegation: StakeDelegation,
    privateKey: PrivateKey
  ): Signed<StakeDelegation> {
    const memo = stakeDelegation.memo ?? "";
    const fee = String(stakeDelegation.fee);
    const nonce = String(stakeDelegation.nonce);
    const validUntil = String(stakeDelegation.validUntil ?? defaultValidUntil);
    return {
      signature: minaSDK.signStakeDelegation(this.network, privateKey, {
        common: {
          fee,
          feePayer: stakeDelegation.from,
          nonce,
          validUntil,
          memo,
        },
        delegationPayload: {
          newDelegate: stakeDelegation.to,
          delegator: stakeDelegation.from,
        },
      }).signature,
      data: {
        to: stakeDelegation.to,
        from: stakeDelegation.from,
        fee,
        nonce,
        memo,
        validUntil,
      },
    };
  }

  /**
   * Verifies a signed stake delegation.
   *
   * @param signedStakeDelegation A signed stake delegation
   * @returns True if the `signed(stakeDelegation)` is a verifiable stake delegation
   */
  public verifyStakeDelegation(
    signedStakeDelegation: Signed<StakeDelegation>
  ): boolean {
    const payload = signedStakeDelegation.data;
    const memo = payload.memo ?? "";
    const fee = String(payload.fee);
    const nonce = String(payload.nonce);
    const validUntil = String(payload.validUntil ?? defaultValidUntil);
    return minaSDK.verifyStakeDelegationSignature(this.network, {
      sender: signedStakeDelegation.data.from,
      signature: signedStakeDelegation.signature,
      stakeDelegation: {
        common: {
          fee,
          feePayer: payload.from,
          nonce,
          validUntil,
          memo,
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
   * @param signedPayment A signed payment transaction
   * @returns A transaction hash
   */
  public hashPayment(signedPayment: Signed<Payment>): string {
    const payload = signedPayment.data;
    const memo = payload.memo ?? "";
    const fee = String(payload.fee);
    const amount = String(payload.amount);
    const nonce = String(payload.nonce);
    const validUntil = String(payload.validUntil ?? defaultValidUntil);
    return minaSDK.hashPayment({
      sender: signedPayment.data.from,
      signature: signedPayment.signature,
      payment: {
        common: {
          fee: fee,
          feePayer: payload.from,
          nonce,
          validUntil,
          memo,
        },
        paymentPayload: {
          source: payload.from,
          receiver: payload.to,
          amount,
        },
      },
    });
  }

  /**
   * Compute the hash of a signed stake delegation.
   *
   * @param signedStakeDelegation A signed stake delegation
   * @returns A transaction hash
   */
  public hashStakeDelegation(
    signedStakeDelegation: Signed<StakeDelegation>
  ): string {
    const payload = signedStakeDelegation.data;
    const memo = payload.memo ?? "";
    const fee = String(payload.fee);
    const nonce = String(payload.nonce);
    const validUntil = String(payload.validUntil ?? defaultValidUntil);
    return minaSDK.hashStakeDelegation({
      sender: signedStakeDelegation.data.from,
      signature: signedStakeDelegation.signature,
      stakeDelegation: {
        common: {
          fee,
          feePayer: payload.from,
          nonce,
          validUntil,
          memo,
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
   * @param signedRosettaTxn A signed Rosetta transaction
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
   * @param publicKey A valid public key
   * @returns A string that represents the hex encoding of a public key.
   */
  public publicKeyToRaw(publicKey: string): string {
    return minaSDK.rawPublicKeyOfPublicKey(publicKey);
  }
}

export = Client;
