import Client from "../src/MinaSigner";

describe("Client Class Initialization", () => {
  let client;

  it("should accept `mainnet` as a valid network parameter", () => {
    client = new Client({ network: "mainnet" });
    expect(client).toBeDefined();
  });

  it("should accept `testnet` as a valid network parameter", () => {
    client = new Client({ network: "testnet" });
    expect(client).toBeDefined();
  });

  it("should throw an error if a value that is not `mainnet` or `testnet` is specified", () => {
    try {
      //@ts-ignore
      client = new Client({ network: "new-network" });
    } catch (error) {
      expect(error).toBeDefined();
    }
  });
});
