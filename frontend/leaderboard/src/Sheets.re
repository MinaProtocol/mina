open SheetsBinding;

let clientId = "";
let clientSecret = "";
let code = "";
let tokenPath = "token.json";
let scopes = [|"https://www.googleapis.com/auth/spreadsheets.readonly"|];

let client =
  oAuth2(~clientId, ~clientSecret, ~redirectURI="http://google.com");

let sheets = sheets({version: "v4", auth: client});

let authUrlConfig = {access_type: "offline", scope: scopes};

let sheetsQuery = {
  spreadsheetId: "1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms",
  range: "Class Data!A2:E",
};

let getSheets = token => {
  setCredentials(~client, ~token);
  get(
    ~sheets,
    ~sheetsQuery,
    (~error, ~res) => {
      Js.log(error);
      Js.log(res.data.values);
    },
  );
};

let createToken = () => {
  getToken(
    ~client,
    ~code,
    (~error, ~token) => {
      Js.log(error);
      setCredentials(~client, ~token);
      Js.Json.stringify(token) |> Node.Fs.writeFileAsUtf8Sync(tokenPath);
    },
  );
};

let printSheets = () => {
  switch (Node.Fs.readFileAsUtf8Sync(tokenPath)) {
  | token => token |> Js.Json.parseExn |> getSheets
  | exception (Js.Exn.Error(_)) => createToken()
  };
};

// uncomment to get a valid code
//Js.log(generateAuthUrl(~client, ~authUrlConfig));

printSheets();