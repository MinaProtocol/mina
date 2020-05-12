open Bindings;

let clientId = "";
let clientSecret = "";
let redirectURI = "";

let tokenPath = "token.json";
let scopes = [|"https://www.googleapis.com/auth/spreadsheets.readonly"|];

let readAndParseToken = () => {
  switch (Node.Fs.readFileAsUtf8Sync(tokenPath)) {
  | token => Some(Js.Json.parseExn(token))
  | exception (Js.Exn.Error(_)) => None
  };
};

let requestURICode = (client, cb) => {
  let authUrlConfig = {GoogleSheets.access_type: "offline", scope: scopes};
  let authUrl = GoogleSheets.generateAuthUrl(client, authUrlConfig);
  Js.log("Authorize this app by visiting this url: " ++ authUrl);

  let readLine =
    Readline.createInterface(
      Readline.interfaceOptions(~input=[%raw "process.stdin"]),
    );

  Readline.question(
    readLine,
    "Enter the code from that page here: ",
    code => {
      switch (code) {
      | "" => cb(Error("No code entered"))
      | _ => cb(Ok(code))
      };
      Readline.close(readLine);
    },
  );
};

let createToken = (client, code, cb) => {
  GoogleSheets.getToken(client, code, (~error, ~token) => {
    switch (Js.Nullable.toOption(error)) {
    | Some(error) => cb(Error(error))
    | None =>
      GoogleSheets.setCredentials(client, token);
      token |> Js.Json.stringify |> Node.Fs.writeFileAsUtf8Sync(tokenPath);
      Js.log("Token stored to: " ++ tokenPath);
      cb(Ok());
    }
  });
};

let getRange = (client, sheetsQuery, cb) => {
  let sheets = GoogleSheets.sheets({version: "v4", auth: client});

  GoogleSheets.get(sheets, sheetsQuery, (~error, ~res) => {
    switch (Js.Nullable.toOption(error)) {
    | None => cb(Ok(res.data.values))
    | Some(error) => cb(Error(error))
    }
  });
};

let createClient = (clientCredentials, cb) => {
  let {GoogleSheets.clientId, clientSecret, redirectURI} = clientCredentials;
  let client = GoogleSheets.oAuth2(~clientId, ~clientSecret, ~redirectURI);

  switch (readAndParseToken()) {
  | Some(token) =>
    GoogleSheets.setCredentials(client, token);
    cb(Ok(client));
  | None =>
    Js.log("Error loading token file");
    requestURICode(client, code => {
      switch (code) {
      | Ok(code) =>
        createToken(client, code, result => {
          switch (result) {
          | Ok () => cb(Ok(client))
          | Error(error) => cb(Error(error))
          }
        })
      | Error(error) => cb(Error(error))
      }
    });
  };
};