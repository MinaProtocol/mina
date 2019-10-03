let log = (w, fmt) => Logger.log("Status", w, fmt);

module GetStatus = [%graphql
  {| query ($publicKey: PublicKey){
         daemonStatus {
           blockchainLength
           uptimeSecs
           peers
           consensusTimeBestTip
           consensusTimeNow
         }
         wallet(publicKey: $publicKey) {
           balance {
             total @bsDecoder(fn: "Graphql.Decoders.int64")
           }
           nonce
       }} |}
];

let handleMessage = msg => {
  ReasonUrql.Client.executeQuery(
    ~client=Graphql.client,
    ~request=
      Graphql.Encoders.(
        GetStatus.make(~publicKey=publicKey(Constants.faucetKey), ())
      ),
    (),
  )
  |> Wonka.forEach((. {ReasonUrql.Client.ClientTypes.response}) =>
       switch (response) {
       | Data(d) =>
         let orUnknown = (
           fun
           | Some(s) => s
           | None => "Unknown"
         );

         let (balance, nonce) =
           switch (d##wallet) {
           | Some(wallet) => (
               Int64.to_string(wallet##balance##total),
               orUnknown(wallet##nonce),
             )
           | None => ("Unknown", "Unknown")
           };
         let blockchainLength =
           Belt.Option.map(d##daemonStatus##blockchainLength, string_of_int)
           |> orUnknown;

         let statusText =
           Messages.status(
             ~blockchainLength,
             ~uptimeSecs=d##daemonStatus##uptimeSecs,
             ~numPeers=Array.length(d##daemonStatus##peers),
             ~consensusTimeBestTip=
               orUnknown(d##daemonStatus##consensusTimeBestTip),
             ~consensusTimeNow=d##daemonStatus##consensusTimeNow,
             ~balance,
             ~nonce,
           );

         Discord.Message.reply(msg, statusText);
       | Error(e) => log(`Error, "Failed getting status: %s", e.message)
       | NotFound => log(`Error, "Got 'NotFound' getting status")
       }
     );
};
