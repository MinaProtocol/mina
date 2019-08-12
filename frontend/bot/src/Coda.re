module Wallets = [%graphql
  {| query getWallets { ownedWallets {
    publicKey @bsDecoder(fn: "Graphql.Decoders.publicKey")
  }} |}
];

let printWallets = () => {
  Graphql.executeQuery(Wallets.make())
  |> Wonka.forEach((. response) =>
       switch (response) {
       | Graphql.Data(data) =>
         print_endline("Wallets:");
         Array.iter(d => print_endline(d##publicKey), data##ownedWallets);
       | _ => print_endline("Error")
       }
     );
};

module AddWallet = [%graphql
  {| mutation addWallet { addWallet {
    publicKey @bsDecoder(fn: "Graphql.Decoders.publicKey")
  }} |}
];

let addWallet = () => {
  Graphql.executeMutation(AddWallet.make())
  |> Wonka.forEach((. response) =>
       switch (response) {
       | Graphql.Data(data) =>
         print_endline("Added: " ++ data##addWallet##publicKey)
       | _ => print_endline("Add failed")
       }
     );
};

module SendPayment = [%graphql
  {| mutation send($from: PublicKey, $to_: PublicKey, $amount: UInt64, $fee: UInt64) {
    sendPayment(input: {from: $from, to:$to_, amount:$amount, fee:$fee}) {
      payment {
        id
        nonce
      }
  }} |}
];

let sendPayment = (~from, ~to_, ~amount, ~fee) => {
  Graphql.executeMutation(
    Graphql.Encoders.(
      SendPayment.make(
        ~from=publicKey(from),
        ~to_=publicKey(to_),
        ~amount=int64(amount),
        ~fee=int64(fee),
        (),
      )
    ),
  );
};
