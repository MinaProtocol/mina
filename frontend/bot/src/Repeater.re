let log = (w, fmt) => Logger.log("Repeater", w, fmt);

let start = (~fromKey, ~toKey, ~amount, ~fee, ~timeout) => {
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
      Coda.sendPayment(~from=fromKey, ~to_=toKey, ~amount, ~fee)
      |> Wonka.forEach((. {ReasonUrql.Client.Types.response}) =>
           switch (response) {
           | Data(data) =>
             let payment = data##sendPayment##payment;
             log(`Info, "Sent: %s", payment##id);
           | Error(e) =>
             log(
               `Error,
               "Send failed (from %s to %s), error: %s",
               fromKey,
               toKey,
               Graphql.combinedErrorToString(e),
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
