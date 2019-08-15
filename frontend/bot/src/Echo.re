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
         stateHash
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

module BlockSet = Belt.MutableSet.String;
let processedBlocks = BlockSet.make();

let sendEcho = (echoKey, fee, {from: userKey, amount}) =>
  if (amount > fee) {
    Coda.sendPayment(
      ~from=echoKey,
      ~to_=userKey,
      ~amount=Int64.sub(amount, fee),
      ~fee,
    )
    |> Wonka.forEach((. response) =>
         switch (response) {
         | Graphql.Data(data) =>
           let payment = data##sendPayment##payment;
           Printf.printf(
             "Echo: sent (to %s): %s\n",
             payment##to_,
             payment##id,
           );
         | Error(e) =>
           Printf.printf(
             "Echo: send failed (sending %s coda from %s to %s), error: %s\n",
             Int64.to_string(amount),
             echoKey,
             userKey,
             e,
           )
         | NotFound =>
           // Shouldn't happen
           print_endline("Echo: Got 'NotFound' sending to " ++ userKey)
         }
       );
  } else {
    Printf.printf(
      "Echo: Not enough coda to echo back to %s (only sent %s coda).\n",
      userKey,
      Int64.to_string(amount),
    );
  };

let checkAlreadyProcessed =
  (. response) => {
    switch (response) {
    | Graphql.Data(data) =>
      let stateHash = data##newBlock##stateHash;
      if (BlockSet.has(processedBlocks, stateHash)) {
        print_endline("Echo: already processed block " ++ stateHash);
        false;
      } else {
        BlockSet.add(processedBlocks, stateHash);
        true;
      };
    | Error(_)
    | NotFound => true
    };
  };

let start = (echoKey, fee) => {
  print_endline("Starting echo on " ++ echoKey);
  Graphql.executeSubscription(
    ListenBlocks.make(~publicKey=Graphql.Encoders.publicKey(echoKey), ()),
  )
  |> Wonka.filter(checkAlreadyProcessed)
  |> Wonka.forEach((. newBlock) =>
       switch (newBlock) {
       | Graphql.Data(d) =>
         d##newBlock##transactions##userCommands
         |> Array.to_list
         |> List.filter(({to_, isDelegation}) =>
              to_ == echoKey && !isDelegation
            )
         |> List.iter(sendEcho(echoKey, fee))
       | Error(e) =>
         print_endline("Echo: error retrieving new block. Message: " ++ e)
       | NotFound =>
         // Shouldn't happen
         print_endline("Echo: Got 'NotFound' while listening to blocks")
       }
     );
};
