export type uint32 = number | bigint | string;
export type uint64 = number | bigint | string;

export type publicKey = string;
export type privateKey = string;
export type network = "mainnet" | "testnet";
export type signableData = message | stakeDelegation | payment;

export type keypair = {
  readonly privateKey: privateKey;
  readonly publicKey: publicKey;
};

export type message = {
  publicKey: publicKey;
  message: string;
};

export type signature = {
  readonly field: string;
  readonly scalar: string;
};

export type signed<signableData> = {
  readonly signature: signature;
  readonly data: signableData;
};

export type stakeDelegation = {
  readonly to: publicKey;
  readonly from: publicKey;
  readonly fee: uint64;
  readonly nonce: uint32;
  readonly memo?: string;
  readonly validUntil?: uint32;
};

export type payment = {
  readonly to: publicKey;
  readonly from: publicKey;
  readonly fee: uint64;
  readonly amount: uint64;
  readonly nonce: uint32;
  readonly memo?: string;
  readonly validUntil?: uint32;
};
