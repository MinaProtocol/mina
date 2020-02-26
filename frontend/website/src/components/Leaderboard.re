type member = {
  username: string,
  nickname: string,
  id: int,
};

type entry = array(string);

/*
 type entry = {
   member,
   score: int,
 };
 */

external parseEntry: Js.Json.t => entry = "%identity";

let fetchLeaderboard = () => {
  //"https://points.o1test.net/api/v1/leaderboard/?ordering=-score",
  ReFetch.fetch(
    "https://sheets.googleapis.com/v4/spreadsheets/1CLX9DF7oFDWb1UiimQXgh_J6jO4fVLJEcEnPVAOfq24/values/B3:C?key="
    ++ Next.Config.google_api_key,
    ~method_=Get,
    ~headers={
      "Accept": "application/json",
      "Content-Type": "application/json",
    },
  )
  |> Promise.bind(Bs_fetch.Response.json)
  |> Promise.map(r => {
       let results =
         Option.bind(Js.Json.decodeObject(r), o => Js.Dict.get(o, "values"));

       switch (Option.bind(results, Js.Json.decodeArray)) {
       | Some(resultsArr) =>
         Array.map(parseEntry, resultsArr)
         ->Array.sub(1, Array.length(resultsArr) - 1)
       | None => [||]
       };
     })
  |> Js.Promise.catch(_ => Promise.return([||]));
};

module Styles = {
  open Css;

  let leaderboardContainer =
    style([
      width(`percent(100.)),
      maxWidth(rem(41.)),
      margin2(~v=`zero, ~h=`auto),
    ]);

  let leaderboard =
    style([
      background(Theme.Colors.hyperlinkAlpha(0.15)),
      width(`percent(100.)),
      borderRadius(px(3)),
      paddingTop(`rem(1.)),
      Theme.Typeface.pragmataPro,
      lineHeight(rem(1.5)),
      color(Theme.Colors.midnight),
      selector(
        "div:nth-child(even)",
        [backgroundColor(`rgba((71, 130, 130, 0.1)))],
      ),
    ]);

  let leaderboardRow =
    style([
      padding2(~v=`zero, ~h=`rem(1.)),
      display(`grid),
      gridColumnGap(rem(1.5)),
      gridTemplateColumns([rem(1.), rem(5.5), rem(5.5), rem(3.5)]),
      media(
        Theme.MediaQuery.notMobile,
        [
          width(`percent(100.)),
          gridTemplateColumns([rem(2.5), `auto, rem(6.), rem(3.5)]),
        ],
      ),
    ]);

  let headerRow =
    merge([
      leaderboardRow,
      Theme.Body.basic_semibold,
      style([color(Theme.Colors.midnight)]),
    ]);

  let cell = style([whiteSpace(`nowrap), overflow(`hidden)]);
  let flexEnd = style([justifySelf(`flexEnd)]);
  let rank = merge([cell, flexEnd]);
  let username = merge([cell, style([textOverflow(`ellipsis)])]);
  let current = merge([cell, style([justifySelf(`flexEnd)])]);
  let total = merge([cell, style([opacity(0.5)])]);
};

module LeaderboardRow = {
  [@react.component]
  let make = (~rank, ~entry) => {
    <>
      <div className=Styles.leaderboardRow>
        <span className=Styles.rank>
          {React.string(string_of_int(rank))}
        </span>
        <span className=Styles.username> {React.string(entry[0])} </span>
        //{React.string(entry.member.nickname)}
        <span className=Styles.current> {React.string(entry[1])} </span>
        //{React.string(string_of_int(entry.score))}
        <span className=Styles.total> {React.string(entry[1])} </span>
      </div>
      //{React.string(string_of_int(entry.score))}
    </>;
  };
};

[@react.component]
let make = () => {
  let (entries, setEntries) =
    React.useState(() => [|[|"Loading...", ""|]|]);

  React.useEffect0(() => {
    fetchLeaderboard() |> Promise.iter(e => setEntries(_ => e));
    None;
  });

  <div className=Styles.leaderboardContainer>
    <div id="testnet-leaderboard" className=Styles.leaderboard>
      <div className=Styles.headerRow>
        <span className=Styles.flexEnd> {React.string("#")} </span>
        <span> {React.string("Username")} </span>
        <span className=Styles.flexEnd> {React.string("Current")} </span>
        <span> {React.string("Total")} </span>
      </div>
      <hr />
      {Array.mapi(
         (i, entry) =>
           <LeaderboardRow
             key={entry[0] ++ string_of_int(i)}
             //key={string_of_int(entry.member.id)}
             rank={i + 1}
             entry
           />,
         entries,
       )
       |> React.array}
    </div>
  </div>;
};
