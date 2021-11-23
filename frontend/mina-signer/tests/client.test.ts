import Client from "../src/MinaSDK";

describe("Client Class Initialization", () => {
  describe("Mainnet network", () => {
    it("should accept `mainnet` as a valid network parameter", () => {
      const client = new Client({ network: "mainnet" });
      expect(client).toBeDefined();
    });
  });

  describe("Testnet network", () => {
    it("should accept `testnet` as a valid network parameter", () => {
      const client = new Client({ network: "testnet" });
      expect(client).toBeDefined();
    });
  });
});
