module Unlock = [%graphql
  {| mutation unlock($password: String, $publicKey: PublicKey) {
      unlockWallet(input: {password: $password, publicKey: $publicKey}) {
          publicKey
        }
  } |}
];

let unlock = (~publicKey, ~password) => {
  let log = (w, fmt) => Logger.log("Unlock", w, fmt);

  ReasonUrql.Client.executeMutation(
    ~client=Graphql.client,
    ~request=
      Unlock.make(
        ~password,
        ~publicKey=Graphql.Encoders.publicKey(publicKey),
        (),
      ),
    (),
  )
  |> Wonka.map((. {ReasonUrql.Client.ClientTypes.response}) =>
       switch (response) {
       | Data(_) => log(`Info, "Unlock successful of %s", publicKey)
       | Error(e) =>
         log(`Error, "Unlock failed for %s, error: %s", publicKey, e.message)
       | NotFound => log(`Error, "Got 'NotFound' unlocking %s", publicKey)
       }
     );
};

module SendPayment = [%graphql
  {| mutation send($from: PublicKey, $to_: PublicKey, $amount: UInt64, $fee: UInt64) {
    sendPayment(input: {from: $from, to:$to_, amount:$amount, fee:$fee}) {
      payment {
        id
        to_: to @bsDecoder(fn: "Graphql.Decoders.publicKey")
      }
  }} |}
];

let sendPayment = (~from, ~to_, ~amount, ~fee, ~password) => {
  unlock(~publicKey=from, ~password)
  |> Wonka.mergeMap((. _success) =>
       ReasonUrql.Client.executeMutation(
         ~client=Graphql.client,
         ~request=
           Graphql.Encoders.(
             SendPayment.make(
               ~from=publicKey(from),
               ~to_=publicKey(to_),
               ~amount=int64(amount),
               ~fee=int64(fee),
               (),
             )
           ),
         (),
       )
     );
};
