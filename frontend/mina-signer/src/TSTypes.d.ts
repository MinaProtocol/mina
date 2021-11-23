export declare type uint32 = number | bigint | string;
export declare type uint64 = number | bigint | string;
export declare type publicKey = string;
export declare type privateKey = string;
export declare type network = "mainnet" | "testnet";
export declare type signableData = message | stakeDelegation | payment;
export declare type keypair = {
    readonly privateKey: privateKey;
    readonly publicKey: publicKey;
};
export declare type message = {
    publicKey: publicKey;
    message: string;
};
export declare type signature = {
    readonly field: string;
    readonly scalar: string;
};
export declare type signed<signableData> = {
    readonly signature: signature;
    readonly data: signableData;
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
