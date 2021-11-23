import Client from "../src/MinaSDK";
import { keypair } from "../src/TSTypes";

describe("Message", () => {
  describe("Mainnet network", () => {
    let client: Client;
    let keypair: keypair;

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
  });

  describe("Testnet network", () => {
    let client: Client;
    let keypair;

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
  });
});
