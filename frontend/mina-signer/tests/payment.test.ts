import Client from "../src/MinaSDK";
import { keypair } from "../src/TSTypes";

describe("Payment", () => {
  describe("Mainnet network", () => {
    let client: Client;
    let keypair: keypair;

    beforeAll(async () => {
      client = new Client({ network: "mainnet" });
      keypair = client.genKeys();
    });

    it("generates a signed payment", () => {
      const payment = client.signPayment(
        {
          to: keypair.publicKey,
          from: keypair.publicKey,
          amount: "1",
          fee: "1",
          nonce: "0",
        },
        keypair.privateKey
      );
      expect(payment.data).toBeDefined();
      expect(payment.signature).toBeDefined();
    });

    it("verifies a signed payment", () => {
      const payment = client.signPayment(
        {
          to: keypair.publicKey,
          from: keypair.publicKey,
          amount: "1",
          fee: "1",
          nonce: "0",
        },
        keypair.privateKey
      );
      const verifiedPayment = client.verifyPayment(payment);
      expect(verifiedPayment).toBeTruthy();
    });

    it("hashes a signed payment", () => {
      const payment = client.signPayment(
        {
          to: keypair.publicKey,
          from: keypair.publicKey,
          amount: "1",
          fee: "1",
          nonce: "0",
        },
        keypair.privateKey
      );
      const hashedPayment = client.hashPayment(payment);
      expect(hashedPayment).toBeDefined();
    });
  });

  describe("Testnet network", () => {
    let client: Client;
    let keypair: keypair;

    beforeAll(async () => {
      client = new Client({ network: "testnet" });
      keypair = client.genKeys();
    });

    it("generates a signed payment", () => {
      const payment = client.signPayment(
        {
          to: keypair.publicKey,
          from: keypair.publicKey,
          amount: "1",
          fee: "1",
          nonce: "0",
        },
        keypair.privateKey
      );
      expect(payment.data).toBeDefined();
      expect(payment.signature).toBeDefined();
    });

    it("verifies a signed payment", () => {
      const payment = client.signPayment(
        {
          to: keypair.publicKey,
          from: keypair.publicKey,
          amount: "1",
          fee: "1",
          nonce: "0",
        },
        keypair.privateKey
      );
      const verifiedPayment = client.verifyPayment(payment);
      expect(verifiedPayment).toBeTruthy();
    });

    it("hashes a signed payment", () => {
      const payment = client.signPayment(
        {
          to: keypair.publicKey,
          from: keypair.publicKey,
          amount: "1",
          fee: "1",
          nonce: "0",
        },
        keypair.privateKey
      );
      const hashedPayment = client.hashPayment(payment);
      expect(hashedPayment).toBeDefined();
    });
  });
});
