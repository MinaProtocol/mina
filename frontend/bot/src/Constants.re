let getEnvOrFail = name =>
  switch (Js.Dict.get(Node.Process.process##env, name)) {
  | Some(value) => value
  | None => failwith({j|Couldn't find env var: `$name`"|j})
  };

let getEnv = (~default, name) =>
  Js.Dict.get(Node.Process.process##env, name)
  ->Belt.Option.getWithDefault(default);

let echoKey = getEnvOrFail("ECHO_PUBLICKEY");
// Optional second echo key
let echoKey2 = Js.Dict.get(Node.Process.process##env, "ECHO_PUBLICKEY_2");
let faucetKey = getEnvOrFail("FAUCET_PUBLICKEY");
let discordApiKey = getEnvOrFail("DISCORD_API_KEY");

let graphqlPort = getEnv(~default=string_of_int(0xc0d), "CODA_GRAPHQL_PORT");
let graphqlHost = getEnv(~default="localhost", "CODA_GRAPHQL_HOST");

let listeningChannels = ["faucet"];
let faucetApproveRole = "faucet-approvers";
let feeAmount = getEnv(~default="5", "FEE_AMOUNT") |> Int64.of_string;
let faucetAmount = Int64.of_int(100);
let cooldownTimeMs = 1000. *. 60. *. 60. *. 3.; // 3 hrs
