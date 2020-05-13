module GoogleSheets = {
  type client;
  type sheets;
  type token = Js.Json.t;

  type clientConfig = {
    clientId: string,
    clientSecret: string,
    redirectURI: string,
  };

  type authUrlConfig = {
    access_type: string,
    scope: array(string),
  };

  type sheetsConfig = {
    version: string,
    auth: client,
  };

  type sheetsQuery = {
    spreadsheetId: string,
    range: string,
  };

  [@bs.scope ("google", "auth")] [@bs.new] [@bs.module "googleapis"]
  external oAuth2:
    (~clientId: string, ~clientSecret: string, ~redirectURI: string) => client =
    "OAuth2";

  [@bs.scope "google"] [@bs.module "googleapis"]
  external sheets: sheetsConfig => sheets = "sheets";

  [@bs.send]
  external generateAuthUrl: (client, authUrlConfig) => string =
    "generateAuthUrl";

  [@bs.send]
  external setCredentials: (client, token) => unit = "setCredentials";

  [@bs.send]
  external getToken:
    (
      client,
      string,
      (~error: Js.Nullable.t(string), ~token: token) => unit
    ) =>
    unit =
    "getToken";

  type data = {values: array(array(string))};
  type res = {data};
  [@bs.scope ("spreadsheets", "values")] [@bs.send]
  external get:
    (
      sheets,
      sheetsQuery,
      (~error: Js.Nullable.t(string), ~res: res) => unit
    ) =>
    unit =
    "get";
};

module Readline = {
  type interface;

  [@bs.deriving abstract]
  type interfaceOptions = {input: in_channel};

  [@bs.module "readline"]
  external createInterface: interfaceOptions => interface = "createInterface";

  [@bs.send]
  external question: (interface, string, string => unit) => unit = "question";

  [@bs.send] external close: interface => unit = "close";
};