open Bindings;
module StringMap = Map.Make(String);

let tokenPath = "token.json";
let scopes = [|"https://www.googleapis.com/auth/spreadsheets"|];

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

let updateRange = (client, sheetsUpdate, cb) => {
  let sheets = GoogleSheets.sheets({version: "v4", auth: client});

  GoogleSheets.update(sheets, sheetsUpdate, (~error, ~res) => {
    switch (Js.Nullable.toOption(error)) {
    | None => cb(Ok(res.data.values))
    | Some(error) => cb(Error(error))
    }
  });
};

let createPublickeyUsernameMap = sheetsData => {
  sheetsData
  |> Array.fold_left(
       (map, user) => {StringMap.add(user[0], user[1], map)},
       StringMap.empty,
     );
};

let createUsernamePointsMap = (pointsMap, pkUsernameMap) => {
  StringMap.fold(
    (pk, username, map) => {
      StringMap.mem(pk, pointsMap)
        ? StringMap.add(username, StringMap.find(pk, pointsMap), map) : map
    },
    pkUsernameMap,
    StringMap.empty,
  );
};

let convertPointsMapToSheetsData = pointsMap => {
  StringMap.fold(
    (key: string, value: int, array) => {
      Array.append([|[|key, string_of_int(value)|]|], array)
    },
    pointsMap,
    [||],
  );
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

let updatePointsColumns = (usernamePointsMap, sheetsData, columnIndex) => {
  // Iterate through all the rows in the fetched Google Sheets data
  Array.iter(
    row => {
      row
      |> Array.iter(rowValue =>
           if (StringMap.mem(rowValue, usernamePointsMap)) {
             // Found a username, get the points to update
             let pointsBinding = StringMap.find(rowValue, usernamePointsMap);
             let pointsValue = int_of_string_opt(row[columnIndex]);

             switch (pointsValue, pointsBinding) {
             | (Some(sheetsValue), pointsBinding) =>
               row[columnIndex] = string_of_int(sheetsValue + pointsBinding)
             | (None, pointsBinding) =>
               // If user as an empty cell, add new points
               row[columnIndex] = string_of_int(pointsBinding)
             };
           }
         )
    },
    Belt.Array.slice(sheetsData, ~offset=1, ~len=Array.length(sheetsData)),
  );
};

let updatePoints = (sheetsData, metricsMap) => {
  // Loop through the first column and calculate listed challenges
  sheetsData[0]
  |> Array.iteri((columnIndex, column) => {
       let pointsMap = Challenges.calculatePoints(column, metricsMap);
       let pkUsernameMap = createPublickeyUsernameMap(sheetsData);
       let usernamePointsMap =
         createUsernamePointsMap(pointsMap, pkUsernameMap);

       // Challenge data detected
       if (StringMap.cardinal(usernamePointsMap) > 0) {
         updatePointsColumns(usernamePointsMap, sheetsData, columnIndex);
       };
     });
};

let uploadPoints = metricsMap => {
  let clientId = "";
  let clientSecret = "";
  let redirectURI = "";
  let spreadsheetId = "";

  let sheetsQuery: GoogleSheets.sheetsQuery = {spreadsheetId, range: ""};

  createClient({clientId, clientSecret, redirectURI}, client => {
    switch (client) {
    | Ok(client) =>
      getRange(client, sheetsQuery, result => {
        switch (result) {
        | Ok(sheetsData) =>
          updatePoints(sheetsData, metricsMap);

          let resource: GoogleSheets.sheetsData = {values: sheetsData};
          let sheetsUpdate: GoogleSheets.sheetsUpdate = {
            spreadsheetId,
            range: "",
            valueInputOption: "USER_ENTERED",
            resource,
          };
          updateRange(client, sheetsUpdate, result => {
            switch (result) {
            | Ok(_) => Js.log("Data uploaded")
            | Error(error) => Js.log(error)
            }
          });
          ();
        | Error(error) => Js.log(error)
        }
      })
    | Error(error) => Js.log(error)
    }
  });
};