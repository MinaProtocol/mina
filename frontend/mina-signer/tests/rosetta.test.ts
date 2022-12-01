import Client from "../src/MinaSigner";

describe("Rosetta", () => {
  let client: Client;

  const signedRosettaTnxMock = `
  {
    "signature": "389ac7d4077f3d485c1494782870979faa222cd906b25b2687333a92f41e40b925adb08705eddf2a7098e5ac9938498e8a0ce7c70b25ea392f4846b854086d43",
    "payment": {
      "to": "B62qnzbXmRNo9q32n4SNu2mpB8e7FYYLH8NmaX6oFCBYjjQ8SbD7uzV",
      "from": "B62qnzbXmRNo9q32n4SNu2mpB8e7FYYLH8NmaX6oFCBYjjQ8SbD7uzV",
      "fee": "10000000",
      "token": "1",
      "nonce": "0",
      "memo": null,
      "amount": "1000000000",
      "valid_until": "4294967295"
    },
    "stake_delegation": null
  }`;

  beforeAll(async () => {
    client = new Client({ network: "mainnet" });
  });

  it("generates a valid rosetta transaction", () => {
    const signedGraphQLCommand =
      client.signedRosettaTransactionToSignedCommand(signedRosettaTnxMock);
    const signedRosettaTnxMockJson = JSON.parse(signedRosettaTnxMock);
    const signedGraphQLCommandJson = JSON.parse(signedGraphQLCommand);

    expect(signedRosettaTnxMockJson.payment.to).toEqual(
      signedGraphQLCommandJson.data.payload.body[1].receiver_pk
    );

    expect(signedRosettaTnxMockJson.payment.from).toEqual(
      signedGraphQLCommandJson.data.payload.body[1].source_pk
    );

    expect(signedRosettaTnxMockJson.payment.amount).toEqual(
      signedGraphQLCommandJson.data.payload.body[1].amount
    );
  });
});
