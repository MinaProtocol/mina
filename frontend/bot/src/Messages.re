let greeting = "you summoned me?";

let help =
  {|
Woof! I can help you get some coda on the testnet.
Just send me a message in the #faucet channel with the following contents:
`$request <public-key>`
Once a mod approves, `|}
  ++ Int64.to_string(Constants.faucetAmount)
  ++ {| coda` will be sent to the requested address!|};

let requestError = {|
Grrrrr... Invalid parameters!!
Try again in this format:
`$request <public-key>`|};

let requestCooldown = (~timeLeft) => {j|
Sorry, you already got some tokens from the faucet recently.
Please wait $timeLeft before requesting again!|j};

let faucetSentNotification = (~id) => {j|
I just sent you some coda!
Transaction id: $id|j};

let faucetFailNotification = (~error) => {j|
I failed to send you some coda just now :sob:
Please try again later!
Error: $error|j};
