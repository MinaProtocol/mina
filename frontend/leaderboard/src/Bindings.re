module Postgres = {
  type pool;
  type connectionString = {connectionString: string};
  type dbResult = {rows: array(Js.Json.t)};

  [@bs.module "pg"] [@bs.new]
  external makePool: connectionString => pool = "Pool";

  [@bs.send]
  external query:
    (pool, string, (~error: Js.Nullable.t(string), ~res: dbResult) => unit) =>
    unit =
    "query";
};

module GoogleSheets = {
  type client;
  type sheets;
  type token = Js.Json.t;
  type cellData;
  type sheetsUploadData = {values: array(array(string))};
  type sheetsData = {values: array(array(cellData))};
  type res = {data: sheetsData};

  type authConfig = {scopes: array(string)};

  type sheetsConfig = {
    version: string,
    auth: client,
  };

  type sheetsQuery = {
    spreadsheetId: string,
    range: string,
    valueRenderOption: string,
  };

  type sheetsUpdate = {
    spreadsheetId: string,
    range: string,
    valueInputOption: string,
    resource: sheetsUploadData,
  };

  [@bs.scope ("google", "auth")] [@bs.new] [@bs.module "googleapis"]
  external googleAuth: authConfig => client = "GoogleAuth";

  [@bs.scope "google"] [@bs.module "googleapis"]
  external sheets: sheetsConfig => sheets = "sheets";

  [@bs.send]
  external getClient:
    (client, (~error: Js.Nullable.t(string), ~token: token) => unit) => unit =
    "getClient";

  [@bs.scope ("spreadsheets", "values")] [@bs.send]
  external get:
    (
      sheets,
      sheetsQuery,
      (~error: Js.Nullable.t(string), ~res: res) => unit
    ) =>
    unit =
    "get";

  [@bs.scope ("spreadsheets", "values")] [@bs.send]
  external update:
    (
      sheets,
      sheetsUpdate,
      (~error: Js.Nullable.t(string), ~res: res) => unit
    ) =>
    unit =
    "update";
};