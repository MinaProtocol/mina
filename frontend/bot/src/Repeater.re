let log = (w, fmt) => Logger.log("Repeater", w, fmt);

let start = (~fromKey, ~toKey, ~amount, ~fee, ~timeout, ~password) => {
  log(
    `Info,
    "Starting -- amount: %s, fee: %s, timeout: %d, from pubkey: %s to pubkey: %s",
    Int64.to_string(amount),
    Int64.to_string(fee),
    timeout,
    fromKey,
    toKey,
  );
  Js.Global.setInterval(
    () =>
      Coda.sendPayment(~from=fromKey, ~to_=toKey, ~amount, ~fee, ~password)
      |> Wonka.forEach((. {ReasonUrql.Client.ClientTypes.response}) =>
           switch (response) {
           | Data(data) =>
             let (`UserCommand payment) = data##sendPayment##payment;
             log(`Info, "Sent: %s", payment##id);
           | Error(e) =>
             log(
               `Error,
               "Send failed (from %s to %s), error: %s",
               fromKey,
               toKey,
               e.message,
             )
           | NotFound =>
             // Shouldn't happen
             log(
               `Error,
               "Got 'NotFound' sending from %s to %s",
               fromKey,
               toKey,
             )
           }
         ),
    timeout,
  );
};
