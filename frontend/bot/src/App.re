open Discord;

let client = Client.createClient();

let handleMessageHelper = msg =>
  switch (Array.to_list(Js.String.split(" ", Message.content(msg)))) {
  | ["$tiny"] => Message.reply(msg, Messages.greeting)
  | ["$help"] => Message.reply(msg, Messages.help)
  | ["$request", pk] => Faucet.handleMessage(msg, pk)
  | ["$request", ..._] => Message.reply(msg, Messages.requestError)
  | _ => ()
  };

let handleMessage = msg =>
  switch (TextChannel.fromChannel(Message.channel(msg))) {
  | None => ()
  | Some(channel) =>
    if (!(Message.author(msg) |> User.bot)
        && List.mem(TextChannel.name(channel), Constants.listeningChannels)) {
      handleMessageHelper(msg);
    }
  };

// Start echo service
Echo.start(Constants.echoKey, Constants.feeAmount);

// Start up optional second echo service
switch (Constants.echoKey2) {
| Some(echoKey2) => Echo.start(echoKey2, Constants.feeAmount)
| None => ()
};

// Start up optional repeater service
switch (Constants.repeaterKey) {
| Some(repeaterKey) =>
  let _intervalID =
    Repeater.start(
      ~fromKey=repeaterKey,
      ~toKey=Constants.faucetKey,
      ~amount=Int64.of_int(0),
      ~fee=Constants.feeAmount,
      ~timeout=Constants.repeatTimeMs,
    );
  ();
| None => ()
};

Client.onReady(client, _ => Logger.log("App", `Info, "Bot is ready"));

Client.onMessage(client, handleMessage);

Client.login(client, Constants.discordApiKey);
