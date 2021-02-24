/*
 UploadLeaderboardData.re has the responsibilities of uploading the
 information needed for the Leaderboard webpage to a Google Sheets tab.

 This information is seperate from points as it's data that is only
 useful for the Leaderboard webpage.

  */

module StringMap = Map.Make(String);
open Sheets;
open Sheets.Core;

/*
   Upload "Genesis Members", "Block Count", and "Participants" to the Data tab
 */
let uploadData = (spreadsheetId, totalBlocks) => {
  let dataSheet = Sheets.getSheet(Sheets.Data);
  let client = createClient();

  getRange(
    client,
    initSheetsQuery(
      spreadsheetId,
      Sheets.getSheet(Sheets.AllTimeLeaderboard).range,
      "FORMATTED_VALUE",
    ),
    result => {
    switch (result) {
    | Ok(sheetsData) =>
      let data = sheetsData |> decodeGoogleSheets;

      let columnHeaders = [|
        "Genesis Members",
        "Block Count",
        "Participants",
        "Last Updated",
      |];

      let statisticsData = [|
        data->Belt.Array.keep(row => {
          /* The 4th column indicates whether the user is a genesis member */
          switch (Belt.Array.get(row, 3)) {
          | Some(genesisMember) =>
            String.length(Belt.Option.getExn(genesisMember)) == 0
              ? false : true
          | None => false
          }
        })
        |> Array.length
        |> string_of_int,
        totalBlocks,
        data |> Array.length |> string_of_int,
      |];

      updateRange(
        client,
        initSheetsUpdate(
          spreadsheetId,
          dataSheet.range,
          "USER_ENTERED",
          Array.append([|columnHeaders|], [|statisticsData|]),
        ),
        result => {
        switch (result) {
        | Ok(_) => Js.log({j|Uploaded to Data spreadsheet|j})
        | Error(error) => Js.log(error)
        }
      });
    | Error(error) => Js.log(error)
    }
  });
};

/*
   Takes a map of users and column values and adds the column value
   to the user row that will be uploaded. If the value in the map was
 */

let addPropertyToUserRow = (users, userColumnValueMap) => {
  users
  |> Array.map(userRow => {
       let username = Belt.Option.getExn(userRow[0]);
       if (StringMap.mem(username, userColumnValueMap)) {
         let columnValue = StringMap.find(username, userColumnValueMap);
         Belt.Array.concat(userRow, [|Some(columnValue)|]);
       } else {
         Belt.Array.concat(userRow, [|None|]);
       };
     });
};

/*
    Iterates through all user rows and creates a map of usernames as keys
    and column values as values. If the username or column value does not exist,
    we don't do anything and move on.
 */
let createColumnUserMap = (columnValue, usernameColumn, userData) => {
  userData
  |> Array.fold_left(
       (map, userRow) => {
         switch (
           Belt.Array.get(userRow, usernameColumn),
           Belt.Array.get(userRow, columnValue),
         ) {
         | (Some(username), Some(columnValue)) =>
           switch (username, columnValue) {
           | (Some(username), Some(column)) =>
             StringMap.add(username, column, map)
           | (_, _) => map
           }
         | (_, _) => map
         }
       },
       StringMap.empty,
     );
};

let addPropertyToUserRow = (columnValue, usernameColumn, pointsData, users) => {
  pointsData
  |> createColumnUserMap(columnValue, usernameColumn)
  |> addPropertyToUserRow(users);
};

let getAllValidUsers = (usernameColumn, userData) => {
  userData
  |> Array.fold_left(
       (a, row) => {
         switch (Belt.Array.get(row, usernameColumn)) {
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

/*
   Queries all rows in the `main` tab and aggregates data on each individual user row.
   The information we are interested in gathering for a particular user is:
     - username column
     - all time points column
     - phase points column
     - release points column
     - all time rank column
     - phase rank column
     - release rank column
     - GFM badge column
     - technical badge column
     - mvp badge column
 */

let computeMemberProfileData = mainData => {
  let mainUserIndex = 2; /* usernames are located in the 3rd column */
  let allTimePoints = 20; /* all time points are located in the 21st column */
  let phasePoints = 17; /* all time points are located in the 17th column */
  let releasePoints = 40; /* all time points are located in the 41st column */

  let allTimeRank = 19; /* all time points are located in the 20th column */
  let phaseRank = 16; /* all time points are located in the 17th column */
  let releaseRank = 41; /* all time points are located in the 42nd column */

  let genesisBadge = 4; /* all time points are located in the 17th column */
  let technicalBadge = 5; /* all time points are located in the 17th column */
  let mvpBadge = 6; /* all time points are located in the 17th column */

  /* compute users */
  getAllValidUsers(mainUserIndex, mainData)
  /* compute all time points */
  |> addPropertyToUserRow(allTimePoints, mainUserIndex, mainData)
  /* compute phase points */
  |> addPropertyToUserRow(phasePoints, mainUserIndex, mainData)
  // /* compute release points */
  |> addPropertyToUserRow(releasePoints, mainUserIndex, mainData)
  // /* compute all time rank */
  |> addPropertyToUserRow(allTimeRank, mainUserIndex, mainData)
  /* compute phase rank */
  |> addPropertyToUserRow(phaseRank, mainUserIndex, mainData)
  /* compute release rank */
  |> addPropertyToUserRow(releaseRank, mainUserIndex, mainData)
  /* compute genesis member badge*/
  |> addPropertyToUserRow(genesisBadge, mainUserIndex, mainData)
  /* compute technical MVP badge */
  |> addPropertyToUserRow(technicalBadge, mainUserIndex, mainData)
  /* compute community MVP badge */
  |> addPropertyToUserRow(mvpBadge, mainUserIndex, mainData);
};

let uploadUserProfileData = spreadsheetId => {
  let client = createClient();

  /* Fetch main leaderboard data */
  getRange(
    client,
    initSheetsQuery(
      spreadsheetId,
      Sheets.getSheet(Sheets.Main).range,
      "FORMATTED_VALUE",
    ),
    result => {
    switch (result) {
    | Ok(mainResult) =>
      let mainData = mainResult |> decodeGoogleSheets;
      let data = computeMemberProfileData(mainData);

      updateRange(
        client,
        initSheetsUpdate(
          spreadsheetId,
          Sheets.getSheet(Sheets.MemberProfileData).range,
          "USER_ENTERED",
          encodeGoogleSheets(data),
        ),
        result => {
        switch (result) {
        | Ok(_) => Js.log({j|Uploaded member data|j})
        | Error(error) => Js.log(error)
        }
      });
    | Error(error) => Js.log(error)
    }
  });
};
