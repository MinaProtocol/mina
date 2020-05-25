module StringMap = Map.Make(String);

let getCellType = v =>
  switch (Js.Types.classify(v)) {
  | JSNumber(float) => `Float(float)
  | JSString(string) => `String(string)
  | _ => failwith("Sheets can only contain string or number")
  };

let decodeGoogleSheets = sheetsData => {
  Array.map(
    row => {
      Array.map(
        cell => {
          switch (getCellType(cell)) {
          | `Float(float) => Some(Js.Float.toString(float))
          | `String(string) => Some(string)
          | _ => None
          }
        },
        row,
      )
    },
    sheetsData,
  );
};

let encodeGoogleSheets = sheetsData => {
  Array.map(
    row => {
      Array.map(
        cell => {
          switch (cell) {
          | Some(cell) => cell
          | None => ""
          }
        },
        row,
      )
    },
    sheetsData,
  );
};

let createPublickeyUsernameMap = sheetsData => {
  sheetsData
  |> Array.fold_left(
       (map, user) => {
         switch (user[0], user[1]) {
         | (Some(publickey), Some(username)) =>
           StringMap.add(publickey, username, map)
         | (_, _) => map
         }
       },
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

let updatePointsColumns =
    (usernamePointsMap, sheetsData, pointIndex, userNameIndex) => {
  // Iterate through all the rows in the fetched Google Sheets data
  Array.iter(
    row => {
      let username =
        switch (row[userNameIndex]) {
        | Some(username) => username
        | None => ""
        };

      if (StringMap.mem(username, usernamePointsMap)) {
        // Found a username, get the points to update
        let pointsBinding = StringMap.find(username, usernamePointsMap);
        let pointsValue =
          switch (row[pointIndex]) {
          | Some(points) => int_of_string_opt(points)
          | None => None
          };

        switch (pointsValue, pointsBinding) {
        | (Some(sheetsValue), pointsBinding) =>
          // Add points from sheets and challenge
          row[pointIndex] = Some(string_of_int(sheetsValue + pointsBinding))
        | (None, pointsBinding) =>
          // If user as an empty cell, add points from challenge
          row[pointIndex] = Some(string_of_int(pointsBinding))
        };
      } else {
        // If username has no points for the challenge, wipe cell
        row[pointIndex] =
          None;
      };
    },
    Belt.Array.slice(sheetsData, ~offset=1, ~len=Array.length(sheetsData)),
  );
};

let getColumnIndex = (data, columnToFind) => {
  Belt.Array.getIndexBy(data, headerName =>
    switch (headerName) {
    | Some(headerName) =>
      String.lowercase_ascii(headerName)
      == String.lowercase_ascii(columnToFind)
    | None => false
    }
  )
  |> Belt.Option.getExn;
};

let updatePoints = (metricsMap, pkUsernameMap, sheetsData) => {
  let userNameIndex = getColumnIndex(sheetsData[0], "Name");
  // Loop through the first row which contains all challenge headers and calculate valid challenges
  sheetsData[0]
  |> Array.iteri((columnIndex, columnHeader) => {
       switch (columnHeader) {
       | Some(columnHeader) =>
         switch (Challenges.calculatePoints(columnHeader, metricsMap)) {
         | Some(pointsMap) =>
           let usernamePointsMap =
             createUsernamePointsMap(pointsMap, pkUsernameMap);
           updatePointsColumns(
             usernamePointsMap,
             sheetsData,
             columnIndex,
             userNameIndex,
           );
         | None => ()
         }
       | None => ()
       }
     });
};

let uploadPoints = (fileCredentials, metricsMap) => {
  let {
    Types.FileCredentials.clientId,
    clientSecret,
    redirectURI,
    spreadsheetId,
  } = fileCredentials;

  Sheets.createClient({clientId, clientSecret, redirectURI}, client => {
    switch (client) {
    | Ok(client) =>
      Sheets.getRange(
        client,
        {
          spreadsheetId,
          range: "PublicKeys!A1:B",
          valueRenderOption: "FORMULA",
        },
        result => {
        switch (result) {
        | Ok(pkUsernameData) =>
          let pkUsernameMap =
            pkUsernameData |> decodeGoogleSheets |> createPublickeyUsernameMap;
          Sheets.getRange(
            client,
            {spreadsheetId, range: "Data!A1:K", valueRenderOption: "FORMULA"},
            result => {
            switch (result) {
            | Ok(leaderboardData) =>
              let decodedResult = decodeGoogleSheets(leaderboardData);
              updatePoints(metricsMap, pkUsernameMap, decodedResult);
              let resource: Bindings.GoogleSheets.sheetsUploadData = {
                values: encodeGoogleSheets(decodedResult),
              };
              Sheets.updateRange(
                client,
                {
                  spreadsheetId,
                  range: "Data!M1",
                  valueInputOption: "USER_ENTERED",
                  resource,
                },
                result => {
                switch (result) {
                | Ok(_) => Js.log("Data uploaded")
                | Error(error) => Js.log(error)
                }
              });
            | Error(error) => Js.log(error)
            }
          });
        | Error(error) => Js.log(error)
        }
      })
    | Error(error) => Js.log(error)
    }
  });
};