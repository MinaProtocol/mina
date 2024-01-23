import Client from "../src/MinaSigner";
import { Keypair } from "../src/TSTypes";

describe("Message", () => {
  describe("Mainnet network", () => {
    let client: Client;
    let keypair: Keypair;

    beforeAll(async () => {
      client = new Client({ network: "mainnet" });
      keypair = client.genKeys();
    });

    it("generates a signed message", () => {
      const message = client.signMessage("hello", keypair);
      expect(message.data).toBeDefined();
      expect(message.signature).toBeDefined();
    });

    it("verifies a signed message", () => {
      const message = client.signMessage("hello", keypair);
      const verifiedMessage = client.verifyMessage(message);
      expect(verifiedMessage).toBeTruthy();
    });

    it("does not verify a signed message from `testnet`", () => {
      const message = client.signMessage("hello", keypair);
      const testnetClient = new Client({ network: "testnet" });
      const invalidMessage = testnetClient.verifyMessage(message);
      expect(invalidMessage).toBeFalsy();
    });
  });

  describe("Testnet network", () => {
    let client: Client;
    let keypair: Keypair;

    beforeAll(async () => {
      client = new Client({ network: "testnet" });
      keypair = client.genKeys();
    });

    it("generates a signed message", () => {
      const message = client.signMessage("hello", keypair);
      expect(message.data).toBeDefined();
      expect(message.signature).toBeDefined();
    });

    it("verifies a signed message", () => {
      const message = client.signMessage("hello", keypair);
      const verifiedMessage = client.verifyMessage(message);
      expect(verifiedMessage).toBeTruthy();
    });

    it("does not verify a signed message from `mainnet`", () => {
      const message = client.signMessage("hello", keypair);
      const mainnet = new Client({ network: "mainnet" });
      const invalidMessage = mainnet.verifyMessage(message);
      expect(invalidMessage).toBeFalsy();
    });
  });
});
