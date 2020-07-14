let log = (w, fmt) => Logger.log("Echo", w, fmt);

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

let sendEcho = (echoKey, fee, password, `UserCommand obj) => {
  let amount = obj##amount;
  let userKey = obj##from;
  if (amount > fee) {
    Coda.sendPayment(
      ~from=echoKey,
      ~to_=userKey,
      ~amount=Int64.sub(amount, fee),
      ~fee,
      ~password,
    )
    |> Wonka.forEach((. {ReasonUrql.Client.ClientTypes.response}) =>
         switch (response) {
         | Data(data) =>
           let x : {.. "payment": [ `UserCommand({ .. "id": string, "to_": Js.String.t }) ]} = data##sendPayment
           let (`UserCommand payment) = x##payment;
           log(`Info, "Sent (to %s): %s", payment##to_, payment##id);
         | Error(e) =>
           log(
             `Error,
             "Send failed (sending %s coda from %s to %s), error: %s",
             Int64.to_string(amount),
             echoKey,
             userKey,
             e.message,
           )
         | NotFound =>
           // Shouldn't happen
           log(`Error, "Got 'NotFound' sending to %s", userKey)
         }
    );
  } else {
    log(
      `Info,
      "Not enough coda to echo back to %s (only sent %s coda).",
      userKey,
      Int64.to_string(amount),
    );
  };
};

let checkAlreadyProcessed =
  (. {ReasonUrql.Client.ClientTypes.response}) => {
    switch (response) {
    | Data(data) =>
      let stateHash = data##newBlock##stateHash;
      if (BlockSet.has(processedBlocks, stateHash)) {
        log(`Info, "Already processed block: %s", stateHash);
        false;
      } else {
        BlockSet.add(processedBlocks, stateHash);
        true;
      };
    | Error(_)
    | NotFound => true
    };
  };

let start = (echoKey, fee, password) => {
  log(`Info, "Starting echo on %s", echoKey);
  ReasonUrql.Client.executeSubscription(
    ~client=Graphql.client,
    ~request=
      ListenBlocks.make(~publicKey=Graphql.Encoders.publicKey(echoKey), ()),
    (),
  )
  |> Wonka.filter(checkAlreadyProcessed)
  |> Wonka.forEach((. {ReasonUrql.Client.ClientTypes.response}) =>
       switch (response) {
       | Data(d) =>
        let userCommands: array([`UserCommand({.. "to_": Js.String.t, "isDelegation": bool, "from": Js.String.t, "amount": int64 })]) = d##newBlock##transactions##userCommands;

         userCommands
         |> Array.to_list
         |> List.filter((`UserCommand cmd) => {
              cmd##to_ == echoKey && !cmd##isDelegation
         })
         |> List.iter(sendEcho(echoKey, fee, password))
       | Error(e) =>
         log(`Error, "Error retrieving new block. Message: %s", e.message)
       | NotFound =>
         // Shouldn't happen
         log(`Error, "Got 'NotFound' while listening to blocks")
       }
     );
};
