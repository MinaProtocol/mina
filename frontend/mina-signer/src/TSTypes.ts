export type UInt32 = number | bigint | string;
export type UInt64 = number | bigint | string;

export type PublicKey = string;
export type PrivateKey = string;
export type Network = "mainnet" | "testnet";

export type Keypair = {
  readonly privateKey: PrivateKey;
  readonly publicKey: PublicKey;
};

export type Message = {
  publicKey: PublicKey;
  message: string;
};

export type Signature = {
  readonly field: string;
  readonly scalar: string;
  readonly signer?: string;
};

export type StakeDelegation = {
  readonly to: PublicKey;
  readonly from: PublicKey;
  readonly fee: UInt64;
  readonly nonce: UInt32;
  readonly memo?: string;
  readonly validUntil?: UInt32;
};

export type Payment = {
  readonly to: PublicKey;
  readonly from: PublicKey;
  readonly fee: UInt64;
  readonly amount: UInt64;
  readonly nonce: UInt32;
  readonly memo?: string;
  readonly validUntil?: UInt32;
};

export type OtherParties = {
  body: any;
  authorization: any;
}[];

export type Party = {
  readonly parties: {
    otherParties: OtherParties;
  };

  readonly feePayer: {
    readonly feePayer: PublicKey;
    readonly fee: UInt64;
    readonly nonce: UInt32;
    readonly memo?: string;
  };
};

export type SignableData = Message | StakeDelegation | Payment | Party;

export type Signed<SignableData> = {
  readonly signature: Signature;
  readonly data: SignableData;
};
