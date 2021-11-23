import Client from "../src/MinaSDK";

describe("Keypair", () => {
  let client: Client;

  beforeAll(async () => {
    client = new Client({ network: "mainnet" });
  });

  it("generates a valid keypair", () => {
    const keypair = client.genKeys();
    expect(keypair.publicKey).toBeDefined();
    expect(keypair.privateKey).toBeDefined();
  });

  it("can verify a valid keypair", () => {
    const keypair = client.genKeys();
    expect(client.verifyKeypair(keypair)).toBeTruthy();
  });

  it("fails to derive an invalid keypair", () => {
    try {
      client.verifyKeypair({ publicKey: "invalid", privateKey: "invalid" });
    } catch (error) {
      expect(error).toBeDefined();
    }
  });

  it("derives an equivalent public key from a private key", () => {
    const keypair = client.genKeys();
    const publicKey = client.derivePublicKey(keypair.privateKey);
    expect(keypair.publicKey).toEqual(publicKey);
  });

  it("can derive a hex-encoded public key from a public key", () => {
    const keypair = client.genKeys();
    const rawPublicKey = client.publicKeyToRaw(keypair.publicKey);
    expect(rawPublicKey).toBeDefined();
  });
});
