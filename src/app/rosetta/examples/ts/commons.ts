import axios, { AxiosInstance } from "axios";
import * as dotenv from "dotenv";

dotenv.config();

export const ROSETTA_URL = process.env.ROSETTA_URL ?? "http://localhost:3087";
export const NETWORK = process.env.NETWORK ?? "devnet";

export const BLOCKCHAIN = "mina";
export const CURVE_TYPE = "pallas";
export const MINA_CURRENCY = { symbol: "MINA", decimals: 9 } as const;
export const DEFAULT_TOKEN_ID =
  "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf";

export const NETWORK_IDENTIFIER = {
  blockchain: BLOCKCHAIN,
  network: NETWORK,
};

export type NetworkIdentifier = typeof NETWORK_IDENTIFIER;

export interface BlockIdentifier {
  index: number;
  hash: string;
}

export interface PartialBlockIdentifier {
  index?: number;
  hash?: string;
}

export interface AccountIdentifier {
  address: string;
  metadata?: { token_id: string };
}

export interface Currency {
  symbol: string;
  decimals: number;
}

export interface Amount {
  value: string;
  currency: Currency;
}

export interface Operation {
  operation_identifier: { index: number };
  related_operations?: { index: number }[];
  type: string;
  status?: string;
  account?: AccountIdentifier;
  amount?: Amount;
  metadata?: Record<string, unknown>;
}

export interface Transaction {
  transaction_identifier: { hash: string };
  operations: Operation[];
  metadata?: Record<string, unknown>;
}

export interface Block {
  block_identifier: BlockIdentifier;
  parent_block_identifier: BlockIdentifier;
  timestamp: number;
  transactions: Transaction[];
  metadata?: Record<string, unknown>;
}

export interface PublicKey {
  hex_bytes: string;
  curve_type: string;
}

export interface Signature {
  signing_payload: SigningPayload;
  public_key: PublicKey;
  signature_type: string;
  hex_bytes: string;
}

export interface SigningPayload {
  account_identifier?: AccountIdentifier;
  hex_bytes: string;
  signature_type?: string;
}

export class RosettaClient {
  private readonly http: AxiosInstance;

  constructor(baseURL: string = ROSETTA_URL) {
    this.http = axios.create({ baseURL, timeout: 30_000 });
  }

  private async post<T>(path: string, body: unknown): Promise<T> {
    try {
      const { data } = await this.http.post<T>(path, body);
      return data;
    } catch (err) {
      if (axios.isAxiosError(err)) {
        if (err.response) {
          const r = err.response.data as { message?: string; details?: unknown };
          throw new Error(
            `${path} ${err.response.status}: ${r.message ?? err.message} ${
              r.details ? JSON.stringify(r.details) : ""
            }`,
          );
        }
        throw new Error(
          `${path}: ${err.message} (is Rosetta running at ${this.http.defaults.baseURL}?)`,
        );
      }
      throw err;
    }
  }

  networkList() {
    return this.post<{ network_identifiers: NetworkIdentifier[] }>(
      "/network/list",
      { metadata: {} },
    );
  }

  networkStatus() {
    return this.post<{
      current_block_identifier: BlockIdentifier;
      current_block_timestamp: number;
      genesis_block_identifier: BlockIdentifier;
      peers: unknown[];
    }>("/network/status", { network_identifier: NETWORK_IDENTIFIER });
  }

  networkOptions() {
    return this.post<{
      version: { rosetta_version: string; node_version: string };
      allow: { operation_types: string[]; operation_statuses: unknown[] };
    }>("/network/options", { network_identifier: NETWORK_IDENTIFIER });
  }

  block(id: PartialBlockIdentifier) {
    return this.post<{ block: Block | null }>("/block", {
      network_identifier: NETWORK_IDENTIFIER,
      block_identifier: id,
    });
  }

  accountBalance(address: string, tokenId: string = DEFAULT_TOKEN_ID) {
    return this.post<{
      block_identifier: BlockIdentifier;
      balances: Amount[];
    }>("/account/balance", {
      network_identifier: NETWORK_IDENTIFIER,
      account_identifier: { address, metadata: { token_id: tokenId } },
    });
  }

  mempool() {
    return this.post<{ transaction_identifiers: { hash: string }[] }>(
      "/mempool",
      { network_identifier: NETWORK_IDENTIFIER },
    );
  }

  searchTransactions(args: {
    address?: string;
    transactionHash?: string;
    limit?: number;
  }) {
    return this.post<{
      transactions: { block_identifier: BlockIdentifier; transaction: Transaction }[];
      total_count: number;
    }>("/search/transactions", {
      network_identifier: NETWORK_IDENTIFIER,
      address: args.address,
      transaction_identifier: args.transactionHash
        ? { hash: args.transactionHash }
        : undefined,
      limit: args.limit,
    });
  }

  constructionDerive(publicKeyHex: string) {
    return this.post<{ account_identifier: AccountIdentifier }>(
      "/construction/derive",
      {
        network_identifier: NETWORK_IDENTIFIER,
        public_key: { hex_bytes: publicKeyHex, curve_type: CURVE_TYPE },
      },
    );
  }

  constructionPreprocess(operations: Operation[]) {
    return this.post<{ options: Record<string, unknown> }>(
      "/construction/preprocess",
      {
        network_identifier: NETWORK_IDENTIFIER,
        operations,
      },
    );
  }

  constructionMetadata(
    options: Record<string, unknown>,
    publicKeys: PublicKey[],
  ) {
    return this.post<{ metadata: Record<string, unknown>; suggested_fee?: Amount[] }>(
      "/construction/metadata",
      {
        network_identifier: NETWORK_IDENTIFIER,
        options,
        public_keys: publicKeys,
      },
    );
  }

  constructionPayloads(
    operations: Operation[],
    metadata: Record<string, unknown>,
    publicKeys: PublicKey[],
  ) {
    return this.post<{
      unsigned_transaction: string;
      payloads: SigningPayload[];
    }>("/construction/payloads", {
      network_identifier: NETWORK_IDENTIFIER,
      operations,
      metadata,
      public_keys: publicKeys,
    });
  }

  constructionCombine(unsignedTransaction: string, signatures: Signature[]) {
    return this.post<{ signed_transaction: string }>("/construction/combine", {
      network_identifier: NETWORK_IDENTIFIER,
      unsigned_transaction: unsignedTransaction,
      signatures,
    });
  }

  constructionSubmit(signedTransaction: string) {
    return this.post<{ transaction_identifier: { hash: string } }>(
      "/construction/submit",
      {
        network_identifier: NETWORK_IDENTIFIER,
        signed_transaction: signedTransaction,
      },
    );
  }
}

/** Build the three operations that represent a MINA transfer. */
export function buildTransferOperations(args: {
  sender: string;
  receiver: string;
  amountNanomina: string;
  feeNanomina: string;
  tokenId?: string;
}): Operation[] {
  const tokenId = args.tokenId ?? DEFAULT_TOKEN_ID;
  const senderAccount = {
    address: args.sender,
    metadata: { token_id: tokenId },
  };
  const receiverAccount = {
    address: args.receiver,
    metadata: { token_id: tokenId },
  };

  return [
    {
      operation_identifier: { index: 0 },
      type: "fee_payment",
      account: senderAccount,
      amount: { value: `-${args.feeNanomina}`, currency: MINA_CURRENCY },
    },
    {
      operation_identifier: { index: 1 },
      type: "payment_source_dec",
      account: senderAccount,
      amount: { value: `-${args.amountNanomina}`, currency: MINA_CURRENCY },
    },
    {
      operation_identifier: { index: 2 },
      related_operations: [{ index: 1 }],
      type: "payment_receiver_inc",
      account: receiverAccount,
      amount: { value: args.amountNanomina, currency: MINA_CURRENCY },
    },
  ];
}

export const sleep = (ms: number) =>
  new Promise<void>((resolve) => setTimeout(resolve, ms));

export function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing env var: ${name}`);
  return value;
}
