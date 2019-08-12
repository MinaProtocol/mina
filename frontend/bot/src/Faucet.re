type user = {lastFaucetRequest: float};

module StringMap = Belt.MutableMap.String;

let users: StringMap.t(user) = StringMap.make();

let formatTimeLeft = diff => {
  let date = Js.Date.fromFloat(diff);
  let hours = Js.Date.getUTCHours(date);
  let mins = Js.Date.getUTCMinutes(date);
  switch (hours > 0., mins > 0.) {
  | (true, true) => {|$hours hours, $mins minutes|}
  | (true, false) => {|$hours hours|}
  | (false, true) => {|$mins minutes|}
  | (false, false) => {|a few more seconds|}
  };
};

let sendFaucetCoda = (userId, msg, pk) => {
  StringMap.set(users, userId, {lastFaucetRequest: Js.Date.now()});
  Coda.sendPayment(
    ~from=Constants.faucetKey,
    ~to_=pk,
    ~amount=Constants.faucetAmount,
    ~fee=Constants.feeAmount,
  )
  |> Wonka.forEach((. response) => {
       let userName = Discord.Message.author(msg) |> Discord.User.username;
       let replyText =
         switch (response) {
         | Graphql.Data(data) =>
           let id = data##sendPayment##payment##id;
           Messages.faucetSentNotification(~userName, ~id);
         | Error(errorMessage) =>
           Messages.faucetFailNotification(~userName, ~error=errorMessage)
         | NotFound =>
           Messages.faucetFailNotification(~userName, ~error="Not sure...")
         };
       Discord.Message.reply(msg, replyText);
     });
};

let handleMessage = (msg, pk) => {
  // Check if the user has requested recently
  let userId = Discord.Message.author(msg) |> Discord.User.id;
  switch (StringMap.get(users, userId)) {
  | None => sendFaucetCoda(userId, msg, pk)
  | Some({lastFaucetRequest}) =>
    // if lastFaucetRequest was recent && user not a faucet_approver, error.
    let diff = Js.Date.now() -. lastFaucetRequest;
    if (diff < Constants.cooldownTimeMs) {
      Discord.Message.reply(
        msg,
        Messages.requestCooldown(
          ~userName=Discord.Message.author(msg) |> Discord.User.username,
          ~timeLeft=formatTimeLeft(diff),
        ),
      );
    } else {
      sendFaucetCoda(userId, msg, pk);
    };
  };
};
