let log = (w, fmt) => Logger.log("Faucet", w, fmt);

module StringMap = Belt.MutableMap.String;

let lastRequestedMap: StringMap.t(float) = StringMap.make();

let formatTimeLeft = diff => {
  let date = Js.Date.fromFloat(diff);
  let hours = Js.Date.getUTCHours(date);
  let mins = Js.Date.getUTCMinutes(date);
  switch (hours > 0., mins > 0.) {
  | (true, true) => {j|$hours hours, $mins minutes|j}
  | (true, false) => {j|$hours hours|j}
  | (false, true) => {j|$mins minutes|j}
  | (false, false) => {j|a few more seconds|j}
  };
};

let sendFaucetCoda = (userId, msg, pk, password) => {
  StringMap.set(lastRequestedMap, userId, Js.Date.now());
  Coda.sendPayment(
    ~from=Constants.faucetKey,
    ~to_=pk,
    ~amount=Constants.faucetAmount,
    ~fee=Constants.feeAmount,
    ~password,
  )
  |> Wonka.forEach((. {ReasonUrql.Client.ClientTypes.response}) => {
       let replyText =
         switch (response) {
         | Data(data) =>
           let id = {let (`UserCommand x) = data##sendPayment##payment; x##id};
           log(`Info, "Sent (to %s): %s", pk, id);
           Messages.faucetSentNotification(~id);
         | Error(e) =>
           log(`Error, "Send failed (to %s), error: %s", pk, e.message);
           Messages.faucetFailNotification(~error=e.message);
         | NotFound =>
           // Shouldn't happen
           log(`Error, "Got 'NotFound' sending to %s", pk);
           Messages.faucetFailNotification(~error="Not found...");
         };
       Discord.Message.reply(msg, replyText);
     });
};

let msgIsFromAdmin = msg => {
  Discord.(
    switch (Message.member(msg)) {
    | None => false
    | Some(member) =>
      let roles = GuildMember.roles(member);
      let isFaucetApprover = r => Role.name(r) == Constants.faucetApproveRole;
      switch (Collection.find(roles, isFaucetApprover)) {
      | Some(_) => true
      | None => false
      };
    }
  );
};

let handleMessage = (msg, pk, password) => {
  // Check if the user has requested recently
  let userId =
    Discord.Message.author(msg)
    |> Discord.User.id
    |> Discord.Snowflake.toString;
  switch (StringMap.get(lastRequestedMap, userId)) {
  | None => sendFaucetCoda(userId, msg, pk, password)
  | Some(lastRequested) =>
    // if lastRequested was recent && user not a faucet_approver, error.
    let diff = Js.Date.now() -. lastRequested;
    if (diff < Constants.cooldownTimeMs && !msgIsFromAdmin(msg)) {
      log(`Info, "Cooling down pubkey %s", pk);
      Discord.Message.reply(
        msg,
        Messages.requestCooldown(
          ~timeLeft=formatTimeLeft(Constants.cooldownTimeMs -. diff),
        ),
      );
    } else {
      sendFaucetCoda(userId, msg, pk, password);
    };
  };
};
