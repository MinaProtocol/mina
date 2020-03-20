open Discord;

let client = Client.createClient();
let log = (w, fmt) => Logger.log("App", w, fmt);

let handleMessageHelper = msg =>
  switch (Array.to_list(Js.String.split(" ", Message.content(msg)))) {
  | ["$tiny"] => Message.reply(msg, Messages.greeting)
  | ["$help"] => Message.reply(msg, Messages.help)
  | ["$request", pk] =>
    Faucet.handleMessage(msg, pk, Constants.faucetPassword)
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

let iterKey = (~key, ~password, ~name, ~f) => {
  switch (key, password) {
  | (Some(key), Some(password)) => f(key, password)
  | (Some(_), None) => log(`Error, "No value for %s", name)
  | _ => ()
  };
};

// Start echo service(s)
iterKey(
  ~key=Constants.echoKey,
  ~password=Constants.echoPassword,
  ~name="ECHO_PASSWORD",
  ~f=(key, password) =>
  Echo.start(key, Constants.feeAmount, password)
);

iterKey(
  ~key=Constants.echoKey2,
  ~password=Constants.echoPassword2,
  ~name="ECHO_PASSWORD2",
  ~f=(key, password) =>
  Echo.start(key, Constants.feeAmount, password)
);

// Start up optional repeater service
iterKey(
  ~key=Constants.repeaterKey,
  ~password=Constants.repeaterPassword,
  ~name="REPEATER_PASSWORD",
  ~f=(key, password) => {
    let _intervalID =
      Repeater.start(
        ~fromKey=key,
        ~toKey=Constants.faucetKey,
        ~amount=Int64.of_int(0),
        ~fee=Constants.repeaterFeeAmount,
        ~timeout=Constants.repeatTimeMs,
        ~password,
      );
    ();
  },
);

Client.onReady(client, _ => Logger.log("App", `Info, "Bot is ready"));

Client.onMessage(client, handleMessage);

Client.login(client, Constants.discordApiKey);
