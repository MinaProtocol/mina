import Client from "../src/MinaSDK";
import { keypair } from "../src/TSTypes";

describe("Stake Delegation", () => {
  describe("Mainnet network", () => {
    let client: Client;
    let keypair: keypair;

    beforeAll(async () => {
      client = new Client({ network: "mainnet" });
      keypair = client.genKeys();
    });

    it("generates a signed staked delegation", () => {
      const delegation = client.signStakeDelegation(
        {
          to: keypair.publicKey,
          from: keypair.publicKey,
          fee: "1",
          nonce: "0",
        },
        keypair.privateKey
      );
      expect(delegation.data).toBeDefined();
      expect(delegation.signature).toBeDefined();
    });

    it("verifies a signed delegation", () => {
      const delegation = client.signStakeDelegation(
        {
          to: keypair.publicKey,
          from: keypair.publicKey,
          fee: "1",
          nonce: "0",
        },
        keypair.privateKey
      );
      const verifiedDelegation = client.verifyStakeDelegation(delegation);
      expect(verifiedDelegation).toBeTruthy();
    });

    it("hashes a signed stake delegation", () => {
      const delegation = client.signStakeDelegation(
        {
          to: keypair.publicKey,
          from: keypair.publicKey,
          fee: "1",
          nonce: "0",
        },
        keypair.privateKey
      );
      const hashedDelegation = client.hashStakeDelegation(delegation);
      expect(hashedDelegation).toBeDefined();
    });
  });

  describe("Testnet network", () => {
    let client: Client;
    let keypair: keypair;

    beforeAll(async () => {
      client = new Client({ network: "testnet" });
      keypair = client.genKeys();
    });

    it("generates a signed staked delegation", () => {
      const delegation = client.signStakeDelegation(
        {
          to: keypair.publicKey,
          from: keypair.publicKey,
          fee: "1",
          nonce: "0",
        },
        keypair.privateKey
      );
      expect(delegation.data).toBeDefined();
      expect(delegation.signature).toBeDefined();
    });

    it("verifies a signed delegation", () => {
      const delegation = client.signStakeDelegation(
        {
          to: keypair.publicKey,
          from: keypair.publicKey,
          fee: "1",
          nonce: "0",
        },
        keypair.privateKey
      );
      const verifiedDelegation = client.verifyStakeDelegation(delegation);
      expect(verifiedDelegation).toBeTruthy();
    });

    it("hashes a signed stake delegation", () => {
      const delegation = client.signStakeDelegation(
        {
          to: keypair.publicKey,
          from: keypair.publicKey,
          fee: "1",
          nonce: "0",
        },
        keypair.privateKey
      );
      const hashedDelegation = client.hashStakeDelegation(delegation);
      expect(hashedDelegation).toBeDefined();
    });
  });
});
