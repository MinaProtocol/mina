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

let leaderBoardGenesisRange = "All-Time Leaderboard!F4:G";
let computeGenesisMembers = (client, spreadsheetId, users, cb) => {
  getRange(
    client,
    initSheetsQuery(
      spreadsheetId,
      leaderBoardGenesisRange,
      "FORMATTED_VALUE",
    ),
    result => {
    switch (result) {
    | Ok(genesisUserData) =>
      let genesisMembers =
        genesisUserData
        |> decodeGoogleSheets
        |> Array.fold_left(
             (set, user) => {
               switch (user[0], user[1]) {
               | (Some(isGenesis), Some(username)) =>
                 String.length(isGenesis) == 0
                   ? set : Belt.Set.String.add(set, username)
               | (_, _) => set
               }
             },
             Belt.Set.String.empty,
           );

      users
      |> Array.iter(userRow => {
           let username = Belt.Option.getExn(userRow[0]);
           if (Belt.Set.String.has(genesisMembers, username)) {
             Js.Array.push(Some("Y"), userRow) |> ignore;
           } else {
             Js.Array.push(Some("N"), userRow) |> ignore;
           };
         });

      cb(Ok());
    | Error(error) => cb(Error(error))
    }
  });
};

let currentPhase = "Phase 3 Leaderboard!D3:I";
let currentRelease = "3.2b";
let uploadUserPointsDataSheet = spreadsheetId => {
  let client = createClient();
  getRange(
    client,
    initSheetsQuery(
      spreadsheetId,
      "All-Time Leaderboard!G4:G",
      "FORMATTED_VALUE",
    ),
    result => {
    switch (result) {
    | Ok(userData) =>
      let users = userData |> decodeGoogleSheets;
      computeGenesisMembers(client, spreadsheetId, users, result => {
        switch (result) {
        | Ok () =>
          uploadUserPointsData(
            client,
            spreadsheetId,
            "User_Points_Data!A2:C",
            users,
          )
        | Error(error) => failwith(error)
        }
      });
      ();
    | Error(error) => Js.log(error)
    }
  });
};
