type member = {
  username: string,
  nickname: string,
  id: int,
};

type entry = {
  member,
  score: int,
};

external parseEntry: Js.Json.t => entry = "%identity";

let fetchLeaderboard = () => {
  ReFetch.fetch(
    "https://points.o1test.net/api/v1/leaderboard/?ordering=-score",
    ~method_=Get,
    ~headers={
      "Accept": "application/json",
      "Content-Type": "application/json",
    },
  )
  |> Promise.bind(Bs_fetch.Response.json)
  |> Promise.map(r => {
       let results =
         Option.bind(Js.Json.decodeObject(r), o =>
           Js.Dict.get(o, "results")
         );

       switch (Option.bind(results, Js.Json.decodeArray)) {
       | Some(resultsArr) => Array.map(parseEntry, resultsArr)
       | None => [||]
       };
     });
};

module Styles = {
  open Css;

  let leaderboardContainer =
    style([
      width(`percent(100.)),
      maxWidth(rem(41.)),
      margin2(~v=`zero, ~h=`auto),
    ]);

  let leaderboardRow =
    style([
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
        ".leaderboard-row > span",
        [textOverflow(`ellipsis), whiteSpace(`nowrap), overflow(`hidden)],
      ),
      selector("div span:last-child", [opacity(0.5)]),
      selector("div span:nth-child(odd)", [justifySelf(`flexEnd)]),
      selector("div", [padding2(~v=`zero, ~h=`rem(1.))]),
      selector(
        "div:nth-child(even)",
        [backgroundColor(`rgba((71, 130, 130, 0.1)))],
      ),
    ]);
};

module LeaderboardRow = {
  [@react.component]
  let make = (~rank, ~entry) => {
    <>
      <div className=Styles.leaderboardRow>
        <span> {React.string(string_of_int(rank))} </span>
        <span> {React.string(entry.member.nickname)} </span>
        <span> {React.string(string_of_int(entry.score))} </span>
        <span> {React.string(string_of_int(entry.score))} </span>
      </div>
    </>;
  };
};

[@react.component]
let make = () => {
  let (entries, setEntries) = React.useState(() => [||]);

  React.useEffect0(() => {
    fetchLeaderboard() |> Promise.iter(e => setEntries(_ => e));
    None;
  });

  <div className=Styles.leaderboardContainer>
    <div id="testnet-leaderboard" className=Styles.leaderboard>
      <div className=Styles.headerRow>
        <span> {React.string("#")} </span>
        <span> {React.string("Username")} </span>
        <span> {React.string("Current")} </span>
        <span> {React.string("Total")} </span>
      </div>
      <hr />
      {Array.mapi(
         (i, entry) =>
           <LeaderboardRow
             key={string_of_int(entry.member.id)}
             rank={i + 1}
             entry
           />,
         entries,
       )
       |> React.array}
    </div>
  </div>;
};
