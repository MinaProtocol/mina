open SheetsBinding;

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
  let authUrlConfig = {access_type: "offline", scope: scopes};
  let authUrl = generateAuthUrl(~client, ~authUrlConfig);
  Js.log("Authorize this app by visiting this url: " ++ authUrl);

  let readLine =
    createInterface(interfaceOptions(~input=[%raw "process.stdin"]));

  question(
    readLine,
    "Enter the code from that page here: ",
    code => {
      switch (code) {
      | "" => cb(Error(code))
      | _ => cb(Ok(code))
      };
      close(readLine);
    },
  );
};

let createToken = (client, code, cb) => {
  getToken(~client, ~code, (~error, ~token) => {
    switch (Js.Nullable.toOption(error)) {
    | Some(error) => cb(Error(error))
    | None =>
      setCredentials(~client, ~token);
      Js.Json.stringify(token) |> Node.Fs.writeFileAsUtf8Sync(tokenPath);
      Js.log("Token stored too: " ++ tokenPath);
      cb(Ok());
    }
  });
};

let getRange = (client, sheetsQuery, cb) => {
  let sheets = sheets({version: "v4", auth: client});

  get(~sheets, ~sheetsQuery, (~error, ~res) => {
    switch (Js.Nullable.toOption(error)) {
    | None => cb(Ok(res.data.values))
    | Some(error) =>
      Js.log("get() returned an error: " ++ error);
      cb(Error(error));
    }
  });
};

let createClient = (clientCredentials, cb) => {
  let {clientId, clientSecret, redirectURI} = clientCredentials;
  let client = oAuth2(~clientId, ~clientSecret, ~redirectURI);

  switch (readAndParseToken()) {
  | Some(token) =>
    setCredentials(~client, ~token);
    cb(Ok(client));
  | None =>
    Js.log("Error loading client token file");
    requestURICode(
      client,
      fun
      | Ok(code) => {
          createToken(
            client,
            code,
            fun
            | Ok () => cb(Ok(client))
            | Error(error) => {
                Js.log(
                  "Error while trying to retrieve access token: " ++ error,
                );
                cb(Error(client));
              },
          );
        }
      | Error(_) => cb(Error(client)),
    );
  };
};