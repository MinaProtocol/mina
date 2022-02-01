# Faux ZK Oracle 
## Summary

This RFC is a continuation and builds upon the mini-RFC written here: https://github.com/MinaProtocol/mina/issues/9306

A common use case that needs to be supported for smart contracts is to pull in some HTTPS-secured data and include it in a smart contract computation. This RFC aims to provide a stub to be used in place of using the full-fledged Oracles that will provide this functionality while they're still under development.

When a smart contract user wants to pull in some HTTPS-secured data, a Faux ZK Oracle can be implemented that provides this basic functionality. The Faux ZK Oracle will have several responsibilities that a smart contract will depend on. 

1. The Faux ZK Oracle must be allowed to send an HTTP GET/POST request on the user’s behalf to retrieve data to be included inside a circuit. For security reasons, the Faux ZK Oracle will only support domains that have been previously white-listed to fetch data from. This is to prevent users from using the Faux ZK Oracle as a malicious proxy. The white list can be implemented as a `.json` configuration file within the project structure.

2. When the Faux ZK Oracle makes this request on behalf of the user and receives a response from the destination API, the data must be transformed into `Field` elements in a sensible way so that the smart contract receiving this data can parse the response in the circuit. The data should be transformed into field elements on the ZK Oracle so that the data can be signed and then verified inside a circuit directly. Additionally, because there is no support for dynamic lookup within array structures inside a circuit, JSON parsing is not an option inside a circuit directly. By encoding the data into fields before sending it back to the user, the user is able to use that data directly in their circuits.

**Note**: A `Field` element is a SnarkyJS primitive that describes a finite prime field. 

3. After the Faux ZK Oracle transforms the response data into `Field` elements, the server will sign the data and include the signature in the response to the user for verification. This signature can then be verified by a SnarkyJS circuit which asserts that the Faux ZK Oracle was indeed the signer of the data and provides proof of authenticity that it came from the Faux ZK Oracle.


## Detailed Design
### ZK Oracle API

The Faux ZK Oracle will be a serverless function hosted on Cloudflare Workers written in TypeScript. Cloudflare Workers is a serverless environment offered by Cloudflare and will automatically handle scaling for the Faux ZK Oracle. By choosing a serverless environment, there is the minimal infrastructure to support, and scaling is handled by Cloudflare. When users want to fetch data from a white-listed source, the request will be sent to the serverless environment that the Faux ZK Oracle is hosted on. The HTTP methods that the ZK Oracle will listen for will be either a `GET` or `POST` request. The behavior for each request will be essentially the same where the request will be forwarded with whatever data has been attached to the request to the destination URL. 

In the spirit of making it easy to use the Faux ZK Oracle, a micro JavaScript library can be implemented which is offers an interface for calling the Faux ZK Oracle. This interface can specify a GET and POST method with input parameters that the user wants to send in their request for data. The following code could be an example of such an interface:

```
function Get(url: string, queryParams: {})
function Post(url: string, postData: {})
```

Once the Faux ZK Oracle receives a successful response from the whitelisted destination, it must transform the data into a data structure consisting of `Field` elements. The data structure used to encode the data into Field elements will be heavily dependent on the response data. For simplicity, we will assume we will also get an array of JSON objects for the initial usage of an MVP. Then we can assume that we will be able to encode a JSON object into an array of Field elements. For each array representing a JSON object, we will append that array to another array that holds all JSON objects. In the end, we will have a 2D array of Field elements.

Once the response data is encoded in a sensible Field data structure, the Faux ZK Oracle will sign the encoded Field data to provide authenticity of the ZK Oracle. This signature will be checked inside a circuit for its authenticity.

### Binance API

For the demo use case, we must use Binance's API to fetch a list of trades from the user. To fetch a list of trades from an account, Binance provides the following route:

[GET /api/v3/myTrades  (HMAC SHA256)](https://github.com/binance/binance-spot-api-docs/blob/master/rest-api.md#account-trade-list-user_data)

**Note**
This API endpoint is a `Signed` endpoint which means there are extra security measures. To make a request to this URL, an additional `signature` parameter is required. This `signature` parameter is an HMAC SHA256 keyed with the user's `API_SECRET`  as the key and then the parameters of the query are hashed as the value. This means we require the `API_SECRET` of the user (this is outlined in the Figma designs already).

Using the previously mentioned micro library, we can make a call to Binance's API as so:
```ts
GET("https://api.binance.com/api/v3/myTrades", {queryParms...})
```


The returned response is an array of JSON objects with the following form:
```json
[
  {
    "symbol": "BNBBTC",
    "id": 28457,
    "orderId": 100234,
    "orderListId": -1,
    "price": "4.00000100",
    "qty": "12.00000000",
    "quoteQty": "48.000012",
    "commission": "10.10000000",
    "commissionAsset": "BNB",
    "time": 1499865549590,
    "isBuyer": true,
    "isMaker": false,
    "isBestMatch": true
  }
]
```


If we receive an error from the Binance API, we can return the same error message back to the client. If we receive a 200 from the Binance API, we will send back the trade data outlined above. Note that if the user has zero trades under the specified properties, an empty list is returned.

### Serializing the Trade History data into Fields

Once the response data is returned to the Faux ZK Oracle, the Oracle must serialize the user’s trade data into `Field` elements so that it can be used inside a circuit. This can be done by including only the information that is needed to calculate a percentage gain/loss for each trade and ignoring all other values. For the `price`, `quantity`, and `timestamp` fields, we can transform these into Field values directly. For the `isBuyer` property, we can encode this value into a `Bool` type which is another SnarkyJS primitive that can be used inside a circuit.

For each individual trade, an array of Field elements with a Bool element will be created. For each array representing a trade, we append that array to another array that will hold all trades. In the end, the Faux ZK Oracle will construct something along the lines of:

```ts
[
	[ 
		Field(price), 
		Field(quantity), 
		Field(timestamp), 
		Bool(isBuyer)
	],
	…
]
```

Once the data is encoded into a 2D array of Fields, we must sign the data with the Mina Signer using a keypair created for the Faux ZK Oracle. By signing the data, we can later check the signature inside a SnarkyJS circuit to confirm if the data has been signed by the correct Faux ZK Oracle private key. 

The object returned to the client from successfully calling the Faux ZK Oracle will be in the form of an object with  `signature` and `data` properties:

```ts
{
	signature: ...
	data: [[...]]
}
```

Once received, the client can pass this data directly into a Smart Contract method and verify the authenticity of the signature.


## Drawbacks
### Verifying a signature from the MinaSigner/Client SDK is not compatible with the Signature type in SnarkyJS
Currently, the MinaSigner uses a different hash scheme from SnarkyJS. This means that we cannot verify a signature that is produced in the MinaSigner using SnarkyJS methods. To enable this functionality, the Mina Signer must support the hash scheme used by SnarkyJS (Kimchi) or vice versa.
NOTE: How long does this take? How hard? 
### Signing a non string
### URLS need to be Whitelisted
Can't run an open proxy because it can be abused for malicious intents.

## Open Questions
### How will we support signing from the MinaSigner and verifying the signature in a circuit? How much time will it take to enable this?
### How will we supporting signing a non-string value from the MinaSigner? Since the circuit will expect Field values, we need to sign those and not strings.

## Help Needed
### Supporting the SnarkyJS hash schema in the Mina Signer 
### We will not be able to pass a string into a circuit so we need the Mina Signer to sign Field elements instead
