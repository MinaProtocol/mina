module SendPayment = [%graphql
  {| mutation send($from: PublicKey, $to_: PublicKey, $amount: UInt64, $fee: UInt64) {
    sendPayment(input: {from: $from, to:$to_, amount:$amount, fee:$fee}) {
      payment {
        id
        to_: to @bsDecoder(fn: "Graphql.Decoders.publicKey")
      }
  }} |}
];

let sendPayment = (~from, ~to_, ~amount, ~fee) => {
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
  );
};

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
  |> Wonka.forEach((. {ReasonUrql.Client.Types.response}) =>
       switch (response) {
       | Data(_) => log(`Info, "Unlock successful of %s", publicKey)
       | Error(e) =>
         log(
           `Error,
           "Unlock failed for %s, error: %s",
           publicKey,
           Js.String.make(e),
         )
       | NotFound => log(`Error, "Got 'NotFound' unlocking %s", publicKey)
       }
     );
};

let unlockOpt = (~publicKey, ~password) => {
  switch (publicKey, password) {
  | (Some(publicKey), Some(password)) => unlock(~publicKey, ~password)
  | (Some(publicKey), None) =>
    Logger.log("Unlock", `Error, "No password provided for %s", publicKey)
  | (None, _) => () // Nothing to unlock
  };
};
