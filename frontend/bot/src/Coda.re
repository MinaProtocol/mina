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
