type publicKey = string;
type privateKey = string;
type proof = string;

[@genType.import "./TSTypes"]
type uint64 = string;

[@genType.import "./TSTypes"]
type uint32 = string;

// Max uint32
let defaultValidUntil = "4294967295";

[@genType]
type keypair = {
  privateKey,
  publicKey,
};

[@genType]
type signature = {
  field: string,
  scalar: string,
};

[@genType]
type signed('signable) = {
  publicKey,
  signature,
  payload: 'signable,
};

type stakeDelegation = {
  [@bs.as "to"]
  to_: publicKey,
  from: publicKey,
  fee: uint64,
  nonce: uint32,
  memo: option(string),
  validUntil: option(uint32),
};

type payment = {
  [@bs.as "to"]
  to_: publicKey,
  from: publicKey,
  fee: uint64,
  amount: uint64,
  nonce: uint32,
  memo: option(string),
  validUntil: option(uint32),
};


// Party Transactions
module Party = {
  type predicated = {
    .
    "body": TODO
  };

  type member('auth) = {
    .
    "authorization": 'auth,
    "data": predicated
  };

  type proof_or_signature = {
    .
    "proof": Js.Undefined.t(proof),
    "signature": Js.Undefined.t(signature)
  };

  type protocolState = {
    .
    "snarkedLedgerHash": Js.Undefined.t(string),
    "snarkedNextAvailableToken": Js.Undefined.t(string),
    "snarkedLedgerHash": Js.Undefined.t(string),
    "timestamp": Js.Undefined.t(string),
    "blockchainLength": Js.Undefined.t(string),
    "lastVrfOutput": Js.Undefined.t(string),
    "totalCurrency": Js.Undefined.t(string),
    "globalSlotSinceHardFork": Js.Undefined.t(string),
    "globalSlotSinceGenesis": Js.Undefined.t(string),
    "stakingEpochData": Js.Undefined.t(string),
    "nextEpochData": Js.Undefined.t(string),
  }

  type t = {
    .
    "feePayer": party(signature),
    "otherParties": array(party(proof_or_signature)),
    "protocolState": protocolState
  };
};

{snappFeePayer: {authorization: "7mXNiius9LJidXL1zLJvUqPrzwmwNeZY7ZhuZGtL84zT16ToXGassr9G9vAP2c6QyBNvT4um42AYJ1sVgeNuadBy6KyWNwMV", data: {predicate: "0", body: {depth: "0",
call_data: "0x0000000000000000000000000000000000000000000000000000000000000000", rollup_events: [], events: [], delta: {sgn: MINUS, magnitude: "15000000000"}, token_id: "1",
update: {timing: {set_or_keep: Keep}, token_symbol: {set_or_keep: Keep}, snapp_uri: {set_or_keep: Keep}, permissions: {set_or_keep: Keep}, verification_key: {set_or_keep: Keep},
delegate: {set_or_keep: Keep}, app_state: [{set_or_keep: Keep}, {set_or_keep: Keep}, {set_or_keep: Keep}, {set_or_keep: Keep}, {set_or_keep: Keep}, {set_or_keep: Keep}, {set_or_keep: Keep}, {set_or_keep: Keep}]},
pk: "B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg"}}}, snappOtherParties: {authorization: {proof_or_signature: None_given}, data: {predicate: {full_or_nonce_or_accept: Accept},
body: {depth: "0", call_data: "0x0000000000000000000000000000000000000000000000000000000000000000", rollup_events: [], events: [], delta: {sgn: PLUS, magnitude: "10000000000"}, token_id: "1",
update: {timing: {set_or_keep: Keep}, token_symbol: {set_or_keep: Keep}, snapp_uri: {set_or_keep: Keep}, permissions: {set_or_keep: Keep}, verification_key: {set_or_keep: Keep}, delegate: {set_or_keep: Keep},
app_state: [{set_or_keep: Keep}, {set_or_keep: Keep}, {set_or_keep: Keep}, {set_or_keep: Keep}, {set_or_keep: Keep}, {set_or_keep: Keep}, {set_or_keep: Keep}, {set_or_keep: Keep}]},
pk: "B62qjJwgq7kNXYHXQsMeyiMWL7fHsnPeuAiPfYd3yTor3eKpK8VV1gG"}}}, snappProtocolState: {next_epoch_data: {epoch_length: {check_or_ignore: Ignore}, lock_checkpoint: {check_or_ignore: Ignore},
start_checkpoint: {check_or_ignore: Ignore}, seed: {check_or_ignore: Ignore}, ledger: {total_currency: {check_or_ignore: Ignore}, hash: {check_or_ignore: Ignore}}},
staking_epoch_data: {epoch_length: {check_or_ignore: Ignore}, lock_checkpoint: {check_or_ignore: Ignore}, start_checkpoint: {check_or_ignore: Ignore}, seed: {check_or_ignore: Ignore},
ledger: {total_currency: {check_or_ignore: Ignore}, hash: {check_or_ignore: Ignore}}}, global_slot_since_genesis: {check_or_ignore: Ignore}, curr_global_slot: {check_or_ignore: Ignore},
total_currency: {check_or_ignore: Ignore}, last_vrf_input: null, min_window_density: {check_or_ignore: Ignore}, blockchain_length: {check_or_ignore: Ignore}, timestamp: {check_or_ignore: Ignore},
snarked_next_available_token: {check_or_ignore: Ignore}, snarked_ledger_hash: {check_or_ignore: Ignore}}}

// ---

type minaSDK;
[@bs.module "./client_sdk.bc.js"] external minaSDK: minaSDK = "minaSDK";

[@bs.send] external genKeys: (minaSDK, unit) => keypair = "genKeys";
/**
  * Generates a public/private keypair
 */
[@genType]
let genKeys = () => genKeys(minaSDK, ());

[@bs.send]
external publicKeyOfPrivateKey: (minaSDK, privateKey) => publicKey =
  "publicKeyOfPrivateKey";
/**
  * Derives the public key of the corresponding private key
  *
  * @param privateKey - The private key used to get the corresponding public key
  * @returns A public key
 */
[@genType]
let derivePublicKey = (privateKey: privateKey) =>
  publicKeyOfPrivateKey(minaSDK, privateKey);

[@bs.send] external validKeypair: (minaSDK, keypair) => bool = "validKeypair";
/**
  * Verifies if a keypair is valid by checking if the public key can be derived from
  * the private key and additionally checking if we can use the private key to
  * sign a transaction. If the keypair is invalid, an exception is thrown.
  *
  * @param keypair - A keypair
  * @returns True if the `keypair` is a verifiable keypair, otherwise throw an exception
  */
[@genType]
let verifyKeypair = (keypair: keypair) => {
  validKeypair(minaSDK, keypair);
};

[@bs.send]
external signString: (minaSDK, privateKey, string) => signature = "signString";
/**
  * Signs an arbitrary message
  *
  * @param key - The keypair used to sign the message
  * @param message - An arbitrary string message to be signed
  * @returns A signed message
 */
[@genType]
let signMessage =
  (. message: string, key: keypair) => {
    publicKey: key.publicKey,
    signature: signString(minaSDK, key.privateKey, message),
    payload: message,
  };

[@bs.send]
external verifyStringSignature: (minaSDK, signature, publicKey, string) => bool =
  "verifyStringSignature";
/**
  * Verifies that a signature matches a message.
  *
  * @param signedMessage - A signed message
  * @returns True if the `signedMessage` contains a valid signature matching
  * the message and publicKey.
 */
[@genType]
let verifyMessage =
  (. signedMessage: signed(string)) => {
    verifyStringSignature(
      minaSDK,
      signedMessage.signature,
      signedMessage.publicKey,
      signedMessage.payload,
    );
  };

/**
 * Same as Option.value, used to avoid bringing in bs-platform as a dep.
 * This is a simplified version that should not be used on nested options.
 * Would be fixed by https://github.com/BuckleScript/bucklescript/pull/2171
 */
let value = (~default: 'a, option: option('a)): 'a => {
  let go = () => [%bs.raw
    {|
    function value($$default, opt) {
      if (opt !== undefined) {
        return opt;
      } else {
        return $$default;
      }
    }
  |}
  ];
  (go())(. default, option);
};

type common_payload_js = {
  .
  "fee": string,
  "feePayer": publicKey,
  "nonce": string,
  "validUntil": string,
  "memo": string,
};

type payment_js = {
  .
  "common": common_payload_js,
  "paymentPayload": {
    .
    "source": publicKey,
    "receiver": publicKey,
    "amount": string,
  },
};

type delegation_payload_js = {
  .
  "delegator": publicKey,
  "newDelegate": publicKey,
};

type stake_delegation_js = {
  .
  "common": common_payload_js,
  "delegationPayload": delegation_payload_js,
};

type signed_js = {
  .
  "stakeDelegation": Js.Undefined.t(stake_delegation_js),
  "payment": Js.Undefined.t(payment_js),
  "sender": publicKey,
  "signature": signature,
};

type signed_payment_js = {
  .
  "payment": payment_js,
  "sender": publicKey,
  "signature": signature,
};

type signed_stake_delegation_js = {
  .
  "stakeDelegation": stake_delegation_js,
  "sender": publicKey,
  "signature": signature,
};

[@bs.send]
external signPayment: (minaSDK, privateKey, payment_js) => signed_js =
  "signPayment";
/**
  * Signs a payment transaction using a private key.
  *
  * This type of transaction allows a user to transfer funds from one account
  * to another over the network.
  *
  * @param payment - An object describing the payment
  * @param key - The keypair used to sign the transaction
  * @returns A signed payment transaction
 */
[@genType]
let signPayment =
  (. payment: payment, key: keypair) => {
    let memo = value(~default="", payment.memo);
    // Stringify all numeric inputs since they may be passed as
    // number/bigint in TS/JS
    let fee = Js.String.make(payment.fee);
    let nonce = Js.String.make(payment.nonce);
    let amount = Js.String.make(payment.amount);
    let validUntil =
      Js.String.make(value(~default=defaultValidUntil, payment.validUntil));
    {
      publicKey: key.publicKey,
      payload: {
        ...payment,
        fee,
        nonce,
        amount,
        // Set missing values so that the signature can be checked without guessing defaults.
        memo: Some(memo),
        validUntil: Some(validUntil),
      },
      signature:
        signPayment(
          minaSDK,
          key.privateKey,
          {
            "common": {
              "fee": fee,
              "feePayer": key.publicKey,
              "nonce": nonce,
              "validUntil": validUntil,
              "memo": memo,
            },
            "paymentPayload": {
              "source": payment.from,
              "receiver": payment.to_,
              "amount": amount,
            },
          },
        )##signature,
    };
  };

[@bs.send]
external signStakeDelegation:
  (minaSDK, privateKey, stake_delegation_js) => signed_js =
  "signStakeDelegation";

/**
  * Signs a stake delegation transaction using a private key.
  *
  * This type of transaction allows a user to delegate their
  * funds from one account to another for use in staking. The
  * account that is delegated to is then considered as having these
  * funds when determining whether it can produce a block in a given slot.
  *
  * @param stakeDelegation - An object describing the stake delegation
  * @param key - The keypair used to sign the transaction
  * @returns A signed stake delegation
 */
[@genType]
let signStakeDelegation =
  (. stakeDelegation: stakeDelegation, key: keypair) => {
    let memo = value(~default="", stakeDelegation.memo);
    // Stringify all numeric inputs since they may be passed as
    // number/bigint in TS/JS
    let fee = Js.String.make(stakeDelegation.fee);
    let nonce = Js.String.make(stakeDelegation.nonce);
    let validUntil =
      Js.String.make(
        value(~default=defaultValidUntil, stakeDelegation.validUntil),
      );
    {
      publicKey: key.publicKey,
      payload: {
        ...stakeDelegation,
        fee,
        nonce,
        // Set missing values so that the signature can be checked without guessing defaults.
        memo: Some(memo),
        validUntil: Some(validUntil),
      },
      signature:
        signStakeDelegation(
          minaSDK,
          key.privateKey,
          {
            "common": {
              "fee": fee,
              "feePayer": key.publicKey,
              "nonce": nonce,
              "validUntil": validUntil,
              "memo": memo,
            },
            "delegationPayload": {
              "newDelegate": stakeDelegation.to_,
              "delegator": stakeDelegation.from,
            },
          },
        )##signature,
    };
  };

[@bs.send]
external verifyPaymentSignature: (minaSDK, signed_payment_js) => bool =
  "verifyPaymentSignature";

/**
  * Verifies a signed payment.
  *
  * @param signedPayment - A signed payment transaction
  * @returns True if the `signed(payment)` is a verifiable payment
  */
[@genType]
let verifyPaymentSignature = (signedPayment: signed(payment)) => {
  let payload = signedPayment.payload;
  // Stringify all numeric inputs since they may be passed as
  // number/bigint in TS/JS
  let memo = value(~default="", payload.memo);
  let fee = Js.String.make(payload.fee);
  let amount = Js.String.make(payload.amount);
  let nonce = Js.String.make(payload.nonce);
  let validUntil =
    Js.String.make(value(~default=defaultValidUntil, payload.validUntil));

  verifyPaymentSignature(
    minaSDK,
    {
      "sender": signedPayment.publicKey,
      "signature": signedPayment.signature,
      "payment": {
        "common": {
          "fee": fee,
          "feePayer": payload.from,
          "nonce": nonce,
          "validUntil": validUntil,
          "memo": memo,
        },
        "paymentPayload": {
          "source": payload.from,
          "receiver": payload.to_,
          "amount": amount,
        },
      },
    },
  );
};

[@bs.send]
external verifyStakeDelegationSignature:
  (minaSDK, signed_stake_delegation_js) => bool =
  "verifyStakeDelegationSignature";

/**
  * Verifies a signed stake delegation.
  *
  * @param signedStakeDelegation - A signed stake delegation
  * @returns True if the `signed(stakeDelegation)` is a verifiable stake delegation
  */
[@genType]
let verifyStakeDelegationSignature =
    (signedStakeDelegation: signed(stakeDelegation)) => {
  let payload = signedStakeDelegation.payload;
  // Stringify all numeric inputs since they may be passed as
  // number/bigint in TS/JS
  let memo = value(~default="", payload.memo);
  let fee = Js.String.make(payload.fee);
  let nonce = Js.String.make(payload.nonce);
  let validUntil =
    Js.String.make(value(~default=defaultValidUntil, payload.validUntil));

  verifyStakeDelegationSignature(
    minaSDK,
    {
      "sender": signedStakeDelegation.publicKey,
      "signature": signedStakeDelegation.signature,
      "stakeDelegation": {
        "common": {
          "fee": fee,
          "feePayer": payload.from,
          "nonce": nonce,
          "validUntil": validUntil,
          "memo": memo,
        },
        "delegationPayload": {
          "newDelegate": payload.to_,
          "delegator": payload.from,
        },
      },
    },
  );
};

[@bs.send]
external hashPayment:
  (minaSDK, signed_payment_js) => string =
  "hashPayment";

/**
  * Compute the hash of a signed payment.
  *
  * @param signedPayment - A signed payment transaction
  * @returns A transaction hash
  */
[@genType]
let hashPayment = (. signedPayment: signed(payment)) => {
  let payload = signedPayment.payload;
  // Stringify all numeric inputs since they may be passed as
  // number/bigint in TS/JS
  let memo = value(~default="", payload.memo);
  let fee = Js.String.make(payload.fee);
  let amount = Js.String.make(payload.amount);
  let nonce = Js.String.make(payload.nonce);
  let validUntil =
    Js.String.make(value(~default=defaultValidUntil, payload.validUntil));

  hashPayment(
    minaSDK,
    {
      "sender": signedPayment.publicKey,
      "signature": signedPayment.signature,
      "payment": {
        "common": {
          "fee": fee,
          "feePayer": payload.from,
          "nonce": nonce,
          "validUntil": validUntil,
          "memo": memo,
        },
        "paymentPayload": {
          "source": payload.from,
          "receiver": payload.to_,
          "amount": amount,
        },
      },
    },
  );
};

[@bs.send]
external hashStakeDelegation:
  (minaSDK, signed_stake_delegation_js) => string =
  "hashStakeDelegation";

/**
  * Compute the hash of a signed stake delegation.
  *
  * @param signedStakeDelegation - A signed stake delegation
  * @returns A transaction hash
  */
[@genType]
let hashStakeDelegation =
    (. signedStakeDelegation: signed(stakeDelegation)) => {
  let payload = signedStakeDelegation.payload;
  // Stringify all numeric inputs since they may be passed as
  // number/bigint in TS/JS
  let memo = value(~default="", payload.memo);
  let fee = Js.String.make(payload.fee);
  let nonce = Js.String.make(payload.nonce);
  let validUntil =
    Js.String.make(value(~default=defaultValidUntil, payload.validUntil));

  hashStakeDelegation(
    minaSDK,
    {
      "sender": signedStakeDelegation.publicKey,
      "signature": signedStakeDelegation.signature,
      "stakeDelegation": {
        "common": {
          "fee": fee,
          "feePayer": payload.from,
          "nonce": nonce,
          "validUntil": validUntil,
          "memo": memo,
        },
        "delegationPayload": {
          "newDelegate": payload.to_,
          "delegator": payload.from,
        },
      },
    },
  );
};

[@bs.send]
external signedRosettaTransactionToSignedCommand: (minaSDK, string) => string =
  "signedRosettaTransactionToSignedCommand";

/**
  * Converts a Rosetta signed transaction to a JSON string that is
  * compatible with GraphQL. The JSON string is a representation of
  * a `Signed_command` which is what our GraphQL expects.
  *
  * @param signedRosettaTxn - A signed Rosetta transaction
  * @returns A string that represents the JSON conversion of a signed Rosetta transaction`.
  */
[@genType]
let signedRosettaTransactionToSignedCommand = (signedRosettaTxn: string) => {
  signedRosettaTransactionToSignedCommand(minaSDK, signedRosettaTxn);
};

[@bs.send]
external rawPublicKeyOfPublicKey: (minaSDK, publicKey) => string =
  "rawPublicKeyOfPublicKey";

/**
  * Return the hex-encoded format of a valid public key. This will throw an exception if
  * the key is invalid or the conversion fails.
  *
  * @param publicKey - A valid public key
  * @returns A string that represents the hex encoding of a public key.
  */
[@genType]
let publicKeyToRaw = (publicKey: string) => {
  rawPublicKeyOfPublicKey(minaSDK, publicKey);
};
