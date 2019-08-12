type userCommands = {
  from: string,
  to_: string,
  amount: int64,
  isDelegation: bool,
};

module ListenBlocks = [%graphql
  {|
     subscription listenBlocks($publicKey: PublicKey) {
       newBlock(publicKey: $publicKey){
         transactions {
           userCommands @bsRecord {
             from @bsDecoder(fn:"Graphql.Decoders.publicKey")
             to_: to @bsDecoder(fn:"Graphql.Decoders.publicKey")
             amount @bsDecoder(fn:"Graphql.Decoders.int64")
             isDelegation
           }
         }
       }
     }
   |}
];

let sendEcho = (echoKey, {from, amount}) => {
  Coda.sendPayment(
    ~from=echoKey,
    ~to_=from,
    ~amount,
    ~fee=Constants.feeAmount,
  )
  |> Wonka.forEach((. response) =>
       switch (response) {
       | Graphql.Data(data) =>
         print_endline("Sent: " ++ data##sendPayment##payment##id)
       | Error(e) =>
         Printf.printf(
           "Echo failed (sending %s coda from %s to %s), error: %s\n",
           Int64.to_string(amount),
           echoKey,
           from,
           Js.String.make(e),
         )
       | NotFound => print_endline("Potential problem with echo.")
       }
     );
};

let start = echoKey => {
  Graphql.executeSubscription(
    ListenBlocks.make(~publicKey=Graphql.Encoders.publicKey(echoKey), ()),
  )
  |> Wonka.forEach((. newBlock) =>
       switch (newBlock) {
       | Graphql.Data(d) =>
         d##newBlock##transactions##userCommands
         |> Array.to_list
         |> List.filter(({to_, isDelegation}) =>
              to_ == echoKey && !isDelegation
            )
         |> List.iter(sendEcho(echoKey))
       | _ => print_endline("Error retrieving new block.")
       }
     );
};
