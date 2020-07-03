/*
 UploadLeaderboardData.re has the responsibilities of uploading the
 information needed for the Leaderboard webpage to a Google Sheets tab.

 This information is seperate from points as it's data that is only
 useful for the Leaderboard webpage.

  */

module StringMap = Map.Make(String);
open Sheets.Bindings;
open Sheets.Core;

let uploadUserPointsData = (client, spreadsheetId, range, sheetsData) => {
  updateRange(
    client,
    initSheetsUpdate(spreadsheetId, range, "USER_ENTERED", sheetsData),
    result => {
    switch (result) {
    | Ok(_) => Js.log({j|Data uploaded to $range|j})
    | Error(error) => Js.log(error)
    }
  });
};

/*
   Upload the total block count to the "Data" sheet
 */
let uploadTotalBlocks = (spreadsheetId, totalBlocks) => {
  let client = createClient();
  getRange(
    client, initSheetsQuery(spreadsheetId, "Data!A1:B", "FORMULA"), result => {
    switch (result) {
    | Ok(sheetsData) =>
      let newSheetsData = sheetsData |> decodeGoogleSheets;
      newSheetsData[0][1] = totalBlocks;
      updateRange(
        client,
        initSheetsUpdate(
          spreadsheetId,
          "Data!A1:B",
          "USER_ENTERED",
          newSheetsData,
        ),
        result => {
        switch (result) {
        | Ok(_) => Js.log({j|Uploaded total blocks|j})
        | Error(error) => Js.log(error)
        }
      });
    | Error(error) => Js.log(error)
    }
  });
};

let computePoints = (pointIndex, userIndex, pointData, users) => {
  let userPoints =
    pointData
    |> Array.fold_left(
         (map, userRow) => {
           switch (
             Belt.Array.get(userRow, userIndex),
             Belt.Array.get(userRow, pointIndex),
           ) {
           | (Some(usernameOption), Some(pointsOption)) =>
             switch (usernameOption, pointsOption) {
             | (Some(username), Some(points)) =>
               StringMap.add(username, points, map)
             | (_, _) => map
             }
           | (_, _) => map
           }
         },
         StringMap.empty,
       );

  users
  |> Array.map(userRow => {
       let username = Belt.Option.getExn(userRow[0]);
       if (StringMap.mem(username, userPoints)) {
         let points = StringMap.find(username, userPoints);
         Belt.Array.concat(userRow, [|Some(points)|]);
       } else {
         userRow;
       };
     });
};

let computeGenesisMembers = (genesisIndex, usernameIndex, genesisData, users) => {
  let genesisMembers =
    genesisData
    |> Array.fold_left(
         (set, user) => {
           switch (
             Belt.Array.get(user, genesisIndex),
             Belt.Array.get(user, usernameIndex),
           ) {
           | (Some(isGenesisOption), Some(usernameOption)) =>
             switch (isGenesisOption, usernameOption) {
             | (Some(isGenesis), Some(username)) =>
               String.length(isGenesis) == 0
                 ? set : Belt.Set.String.add(set, username)
             | (_, _) => set
             }
           | (_, _) => set
           }
         },
         Belt.Set.String.empty,
       );

  users
  |> Array.map(userRow => {
       let username = Belt.Option.getExn(userRow[0]);
       if (Belt.Set.String.has(genesisMembers, username)) {
         Belt.Array.concat(userRow, [|Some("Y")|]);
       } else {
         Belt.Array.concat(userRow, [|Some("N")|]);
       };
     });
};

let computeUsers = (userIndex, userData) => {
  userData
  |> Array.fold_left(
       (a, row) => {
         switch (Belt.Array.get(row, userIndex)) {
         | Some(usernameOption) =>
           switch (usernameOption) {
           | Some(username) => Array.append(a, [|[|Some(username)|]|])
           | None => a
           }
         | None => a
         }
       },
       [||],
     );
};

/* TODO: Make this better */
let computeRank = (pointIndex, userIndex, releaseData, users) => {
  let f = ((_, val1), (_, val2)) => {
    compare(val1, val2);
  };

  let result =
    releaseData
    |> Array.fold_left(
         (a, userRow) => {
           switch (
             Belt.Array.get(userRow, userIndex),
             Belt.Array.get(userRow, pointIndex),
           ) {
           | (Some(username), Some(points)) =>
             Array.append(
               a,
               [|
                 (
                   Belt.Option.getExn(username),
                   int_of_string(Belt.Option.getExn(points)),
                 ),
               |],
             )
           | (_, _) => a
           }
         },
         [||],
       );

  Array.sort(f, result);
  Belt.Array.reverseInPlace(result);

  let places =
    Array.mapi(
      (index, user) => {
        let (username, _) = user;
        (username, string_of_int(index + 1));
      },
      result,
    )
    |> Array.fold_left(
         (map, user) => {
           let (name, place) = user;
           StringMap.add(name, place, map);
         },
         StringMap.empty,
       );

  users
  |> Array.map(userRow => {
       let username = Belt.Option.getExn(userRow[0]);
       if (StringMap.mem(username, places)) {
         let points = StringMap.find(username, places);
         Belt.Array.concat(userRow, [|Some(points)|]);
       } else {
         userRow;
       };
     });
};

let computeMemberProfileData = (allTimeData, phaseData) => {
  let allTimeUserIndex = 4; /* usernames are located in the 4th column */
  let phaseUserIndex = 2; /* usernames are located in the 2nd column */

  /* compute users */
  computeUsers(4, allTimeData)
  /* compute genesis */
  |> computeGenesisMembers(3, allTimeUserIndex, allTimeData)
  /* compute all time points */
  |> computePoints(5, allTimeUserIndex, allTimeData)
  /* compute phase points */
  |> computePoints(3, phaseUserIndex, phaseData)
  /* compute release points */
  |> computePoints(6, phaseUserIndex, phaseData)
  /* compute all time rank */
  |> computePoints(0, allTimeUserIndex, allTimeData)
  /* compute phase rank */
  |> computePoints(0, phaseUserIndex, phaseData)
  /* compute release rank */
  |> computeRank(6, phaseUserIndex, phaseData);
};

let currentPhase = "Phase 3 Leaderboard!D3:I";
let currentRelease = "3.2b";
let uploadUserPointsDataSheet = spreadsheetId => {
  let client = createClient();
  /* Fetch All-Time leaderboard data */
  getRange(
    client,
    initSheetsQuery(
      spreadsheetId,
      "All-Time Leaderboard!C4:H",
      "FORMATTED_VALUE",
    ),
    result => {
    switch (result) {
    | Ok(allTimeResult) =>
      let allTimeData = allTimeResult |> decodeGoogleSheets;
      /* Fetch current Phase leaderboard data */
      getRange(
        client,
        initSheetsQuery(
          spreadsheetId,
          "Phase 3 Leaderboard!B4:Z",
          "FORMATTED_VALUE",
        ),
        result => {
        switch (result) {
        | Ok(phaseResult) =>
          let phaseData = phaseResult |> decodeGoogleSheets;

          let data = computeMemberProfileData(allTimeData, phaseData);

          updateRange(
            client,
            initSheetsUpdate(
              spreadsheetId,
              "Member_Profile_Data!A2:Z",
              "USER_ENTERED",
              data,
            ),
            result => {
            switch (result) {
            | Ok(_) => Js.log({j|Uploaded member data|j})
            | Error(error) => Js.log(error)
            }
          });
          ();
        | Error(error) => ()
        }
      });
    | Error(error) => Js.log(error)
    }
  });
};
