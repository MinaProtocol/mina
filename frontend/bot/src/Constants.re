let getEnvOrFail = name =>
  switch (Js.Dict.get(Node.Process.process##env, name)) {
  | Some(value) => value
  | None => failwith({j|Couldn't find env var: `$name`"|j})
  };

let getEnv = (~default, name) =>
  Js.Dict.get(Node.Process.process##env, name)
  ->Belt.Option.getWithDefault(default);

let getEnvOpt = name => Js.Dict.get(Node.Process.process##env, name);

let echoKey = getEnvOpt("ECHO_PUBLICKEY");
let echoPassword = getEnvOpt("ECHO_PASSWORD");
let echoKey2 = getEnvOpt("ECHO_PUBLICKEY_2");
let echoPassword2 = getEnvOpt("ECHO_PASSWORD_2");
let repeaterKey = getEnvOpt("REPEATER_PUBLICKEY");
let repeaterPassword = getEnvOpt("REPEATER_PASSWORD");
let faucetKey = getEnvOrFail("FAUCET_PUBLICKEY");
let faucetPassword = getEnvOrFail("FAUCET_PASSWORD");

let discordApiKey = getEnvOrFail("DISCORD_API_KEY");

let graphqlPort = getEnv(~default=string_of_int(0xc0d), "CODA_GRAPHQL_PORT");
let graphqlHost = getEnv(~default="localhost", "CODA_GRAPHQL_HOST");

let listeningChannels = ["faucet"];
let faucetApproveRole = "faucet-approvers";

let feeAmount = getEnv(~default="5", "FEE_AMOUNT") |> Int64.of_string;
let repeaterFeeAmount =
  getEnv(~default=Int64.to_string(feeAmount), "REPEATER_FEE_AMOUNT")
  |> Int64.of_string;

let faucetAmount = Int64.of_int(100);
let cooldownTimeMs = 1000. *. 60. *. 60. *. 3.; // 3 hrs
let repeatTimeMs = 1000 * 60 * 3; // 3 mins
