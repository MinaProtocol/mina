/*
  Upload.re has the responsibilities of managing all logic with the Leaderboard
  Google Sheets .

  The entry point to upload points is uploadPoints(). uploadPoints() expects
  that there is an environment variable for the spreadsheet id, otherwise it will
  report an error.

  The fetched Google Sheets data is in a form of an array of rows. Each entry
  in the array is another array that represents cell values for a particular user.

  The first fetch that is done is to compute a mapping of usernames and public keys
  which is contained in the "users" tab and is then used to match on the
  challenge points map that was computed. Once points are rewarded, updatePointsColumns()
  is executed and the data is then uploaded to the spreadsheet.
 */

module StringMap = Map.Make(String);

let getCellType = v =>
  switch (Js.Types.classify(v)) {
  | JSNumber(float) => `Float(float)
  | JSString(string) => `String(string)
  | _ => failwith("Sheets can only contain string or number")
  };

let decodeGoogleSheets = sheetsData => {
  sheetsData
  |> Array.map(row => {
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
     });
};

let encodeGoogleSheets = sheetsData => {
  sheetsData
  |> Array.map(row => {
       Array.map(
         cell => {
           switch (cell) {
           | Some(cell) => cell
           | None => ""
           }
         },
         row,
       )
     });
};

let getColumnIndex = (data, columnToFind) => {
  Belt.Array.getIndexBy(data, headerName =>
    switch (headerName) {
    | Some(headerName) =>
      String.lowercase_ascii(headerName)
      == String.lowercase_ascii(columnToFind)
    | None => false
    }
  );
};

let normalizeGoogleSheets = sheetsData => {
  let headerLength = Array.length(sheetsData[0]);

  sheetsData
  |> Array.map(row => {
       let rowLength = Array.length(row);
       if (rowLength < headerLength) {
         Array.append(row, ArrayLabels.make(headerLength - rowLength, None));
       } else {
         row;
       };
     });
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

let createUsernamePointsMap = (pointsMap, userMap) => {
  StringMap.fold(
    (username, pk, map) => {
      StringMap.mem(pk, pointsMap)
        ? StringMap.add(username, StringMap.find(pk, pointsMap), map) : map
    },
    userMap,
    StringMap.empty,
  );
};

let updatePointsColumns =
    (usernamePointsMap, sheetsData, pointIndex, userNameIndex) => {
  // Iterate through all the rows in the fetched Google Sheets data
  Belt.Array.slice(sheetsData, ~offset=1, ~len=Array.length(sheetsData))
  |> Array.iter(row => {
       let username =
         switch (row[userNameIndex]) {
         | Some(username) => username
         | None => ""
         };

       if (StringMap.mem(username, usernamePointsMap)) {
         // Found a username, get the points to update
         let pointsBinding = StringMap.find(username, usernamePointsMap);
         // Add points from challenge
         row[pointIndex] = Some(string_of_int(pointsBinding));
       } else {
         // If username has no points for the challenge, wipe cell
         row[pointIndex] =
           None;
       };
     });
};

let filterMetricsMap = (metricsMap, userMap) => {
  let userPublickeys =
    StringMap.bindings(userMap) |> List.map(((_, publickey)) => publickey);
  metricsMap
  |> StringMap.filter((publickey, _) => {
       List.mem(publickey, userPublickeys)
     });
};

let findChallenges = (metricsMap, userMap, sheetsData, usernameIndex) => {
  // Loop through the first row which contains all challenge headers and calculate valid challenges
  sheetsData[0]
  |> Array.iteri((columnIndex, columnHeader) => {
       switch (columnHeader) {
       | Some(challengeHeader) =>
         let filteredMetrics = filterMetricsMap(metricsMap, userMap);
         switch (Challenges.calculatePoints(challengeHeader, filteredMetrics)) {
         | Some(pointsMap) =>
           let usernamePointsMap =
             createUsernamePointsMap(pointsMap, userMap);
           updatePointsColumns(
             usernamePointsMap,
             sheetsData,
             columnIndex,
             usernameIndex,
           );
           ();
         | None => ()
         };
       | None => ()
       }
     });
};

let updatePoints = (metricsMap, userMap, sheetsData) => {
  switch (getColumnIndex(sheetsData[0], "Name")) {
  | Some(usernameIndex) =>
    findChallenges(metricsMap, userMap, sheetsData, usernameIndex)
  | None => ()
  };
};

let updateSheets = (client, spreadsheetId, range, userMap, metricsMap) => {
  Sheets.getRange(
    client, {spreadsheetId, range, valueRenderOption: "FORMULA"}, result => {
    switch (result) {
    | Ok(leaderboardData) =>
      let decodedResult =
        leaderboardData |> decodeGoogleSheets |> normalizeGoogleSheets;
      updatePoints(metricsMap, userMap, decodedResult);
      let resource: Bindings.GoogleSheets.sheetsUploadData = {
        values: encodeGoogleSheets(decodedResult),
      };
      Sheets.updateRange(
        client,
        {spreadsheetId, range, valueInputOption: "USER_ENTERED", resource},
        result => {
        switch (result) {
        | Ok(_) => Js.log({j|Data uploaded to $range|j})
        | Error(error) => Js.log(error)
        }
      });
    | Error(error) => Js.log(error)
    }
  });
};

[@bs.val]
external spreadsheetId: Js.Undefined.t(string) = "process.env.SPREADSHEET_ID";
let uploadPoints = metricsMap => {
  switch (Js.undefinedToOption(spreadsheetId)) {
  | Some(spreadsheetId) =>
    let client =
      Bindings.GoogleSheets.googleAuth({
        Bindings.GoogleSheets.scopes: [|
          "https://www.googleapis.com/auth/spreadsheets",
        |],
      });
    Sheets.getRange(
      client,
      {spreadsheetId, range: "Users!A2:B", valueRenderOption: "FORMULA"},
      result => {
      switch (result) {
      | Ok(userData) =>
        let userMap =
          userData |> decodeGoogleSheets |> createPublickeyUsernameMap;
        updateSheets(client, spreadsheetId, "3.2b!A3:M", userMap, metricsMap);
      | Error(error) => Js.log(error)
      }
    });
  | None => Js.log("Invalid spreadsheet ID")
  };
};

let uploadBlockHeight = blockHeight => {
  switch (Js.undefinedToOption(spreadsheetId)) {
  | Some(spreadsheetId) =>
    let client =
      Bindings.GoogleSheets.googleAuth({
        Bindings.GoogleSheets.scopes: [|
          "https://www.googleapis.com/auth/spreadsheets",
        |],
      });
    Sheets.getRange(
      client,
      {spreadsheetId, range: "Data!A1:B", valueRenderOption: "FORMULA"},
      result => {
      switch (result) {
      | Ok(sheetsData) =>
        let newSheetsData = sheetsData |> decodeGoogleSheets;
        newSheetsData[0][1] = blockHeight;
        let resource: Bindings.GoogleSheets.sheetsUploadData = {
          values: encodeGoogleSheets(newSheetsData),
        };
        Sheets.updateRange(
          client,
          {
            spreadsheetId,
            range: "Data!A1:B",
            valueInputOption: "USER_ENTERED",
            resource,
          },
          result => {
          switch (result) {
          | Ok(_) => Js.log({j|Uploaded block height|j})
          | Error(error) => Js.log(error)
          }
        });
      | Error(error) => Js.log(error)
      }
    });
  | None => Js.log("Invalid spreadsheet ID")
  };
};