type member = {
  name: string,
  genesisMember: bool,
  phasePoints: int,
  releasePoints: int,
  allTimePoints: int,
  releaseRank: int,
  phaseRank: int,
  allTimeRank: int,
};

type entry = array(string);

external parseEntry: Js.Json.t => entry = "%identity";

let safeArrayGet = (index, a) => {
  switch (Belt.Array.get(a, index)) {
  | Some(v) => v
  | None => ""
  };
};

let safeParseInt = str =>
  try(int_of_string(str)) {
  | Failure(_) => 0
  };

let fetchLeaderboard = () => {
  Sheets.fetchRange(
    ~sheet="1Nq_Y76ALzSVJRhSFZZm4pfuGbPkZs2vTtCnVQ1ehujE",
    ~range="Member_Profile_Data!A2:Z",
  )
  |> Promise.map(res => {
       Array.map(parseEntry, res)
       |> Array.map(entry => {
            {
              name: entry |> safeArrayGet(0),
              genesisMember:
                entry |> safeArrayGet(1) |> String.length == 0 ? false : true,
              allTimePoints: entry |> safeArrayGet(2) |> safeParseInt,
              phasePoints: entry |> safeArrayGet(3) |> safeParseInt,
              releasePoints: entry |> safeArrayGet(4) |> safeParseInt,
              allTimeRank: entry |> safeArrayGet(5) |> safeParseInt,
              phaseRank: entry |> safeArrayGet(6) |> safeParseInt,
              releaseRank: entry |> safeArrayGet(7) |> safeParseInt,
            }
          })
     })
  |> Js.Promise.catch(_ => Promise.return([||]));
};

module Styles = {
  open Css;

  let leaderboardContainer =
    style([
      width(`percent(100.)),
      margin2(~v=`zero, ~h=`auto),
      selector("hr", [margin(`zero)]),
    ]);

  let leaderboard =
    style([
      background(white),
      width(`percent(100.)),
      borderRadius(px(3)),
      paddingTop(`rem(1.)),
      Theme.Typeface.ibmplexsans,
      fontSize(rem(1.5)),
      lineHeight(rem(1.5)),
      color(Theme.Colors.leaderboardMidnight),
      selector(
        "div:nth-child(even)",
        [backgroundColor(`rgba((245, 245, 245, 1.)))],
      ),
    ]);

  let leaderboardRow =
    style([
      cursor(`pointer),
      padding2(~v=`rem(1.), ~h=`rem(1.)),
      display(`grid),
      gridColumnGap(rem(1.5)),
      gridTemplateColumns([
        rem(1.),
        rem(5.5),
        rem(5.5),
        rem(3.5),
        rem(3.5),
      ]),
      media(
        Theme.MediaQuery.notMobile,
        [
          width(`percent(100.)),
          gridTemplateColumns([
            rem(3.5),
            `auto,
            rem(9.),
            rem(8.),
            rem(8.),
          ]),
        ],
      ),
    ]);

  let headerRow =
    merge([
      leaderboardRow,
      style([
        paddingBottom(`rem(0.5)),
        fontSize(`rem(1.)),
        fontWeight(`semiBold),
        textTransform(`uppercase),
        letterSpacing(`rem(0.125)),
      ]),
    ]);

  let cell = style([whiteSpace(`nowrap), overflow(`hidden)]);
  let flexEnd = style([justifySelf(`flexEnd), cursor(`default)]);
  let rank = merge([cell, flexEnd]);
  let username =
    merge([cell, style([textOverflow(`ellipsis), fontWeight(`semiBold)])]);
  let pointsCell = merge([cell, style([justifySelf(`flexEnd)])]);
  let activePointsCell =
    merge([cell, style([justifySelf(`flexEnd), fontWeight(`semiBold)])]);
  let inactivePointsCell = merge([pointsCell, style([opacity(0.5)])]);

  let loading =
    style([
      padding(`rem(5.)),
      color(Theme.Colors.leaderboardMidnight),
      textAlign(`center),
    ]);
};

module LeaderboardRow = {
  [@react.component]
  let make = (~rank, ~member) => {
    let _userSlug =
      "/memberProfile"
      ++ "?allTimeRank="
      ++ member.allTimeRank->string_of_int
      ++ "&allTimePoints="
      ++ member.allTimePoints->string_of_int
      ++ "&phaseRank="
      ++ member.phaseRank->string_of_int
      ++ "&phasePoints="
      ++ member.phasePoints->string_of_int
      ++ "&releaseRank="
      ++ member.releaseRank->string_of_int
      ++ "&releasePoints="
      ++ member.releasePoints->string_of_int
      ++ "&genesisMember="
      ++ member.genesisMember->string_of_bool
      ++ "&name="
      ++ member.name
      |> Js.String.replaceByRe([%re "/#/g"], "%23"); /* replace "#" with percent encoding for the URL to properly parse */

    // <Next.Link href=userSlug _as=userSlug>
    <div className=Styles.leaderboardRow>
      <span className=Styles.rank>
        {React.string(string_of_int(rank))}
      </span>
      <span className=Styles.username> {React.string(member.name)} </span>
      <span className=Styles.activePointsCell>
        {React.string(string_of_int(member.releasePoints))}
      </span>
      <span className=Styles.inactivePointsCell>
        {React.string(string_of_int(member.phasePoints))}
      </span>
      <span className=Styles.inactivePointsCell>
        {React.string(string_of_int(member.allTimePoints))}
      </span>
    </div>;
    // </Next.Link>
  };
};

type filter =
  | All
  | Genesis
  | NonGenesis;

type sort =
  | Release
  | Phase
  | AllTime;

type state = {
  loading: bool,
  members: array(member),
};
let initialState = {loading: true, members: [||]};

type actions =
  | UpdateMembers(array(member));

let reducer = (_, action) => {
  switch (action) {
  | UpdateMembers(members) => {loading: false, members}
  };
};

[@react.component]
let make = () => {
  let (state, dispatch) = React.useReducer(reducer, initialState);

  React.useEffect0(() => {
    fetchLeaderboard() |> Promise.iter(e => dispatch(UpdateMembers(e)));
    None;
  });

  <div className=Styles.leaderboardContainer>
    <div id="testnet-leaderboard" className=Styles.leaderboard>
      <div className=Styles.headerRow>
        <span className=Styles.flexEnd> {React.string("Rank")} </span>
        <span className={Css.style([Css.cursor(`default)])}>
          {React.string("Name")}
        </span>
        <span className=Styles.flexEnd> {React.string("This Release")} </span>
        <span className=Styles.flexEnd> {React.string("This Phase")} </span>
        <span className=Styles.flexEnd> {React.string("All Time")} </span>
      </div>
      <hr />
      {Array.map(
         member =>
           <LeaderboardRow
             key={string_of_int(member.allTimeRank)}
             rank={member.allTimeRank}
             member
           />,
         // Array.length(state.members) > 0
         //  ? Array.sub(state.members, 0, 10) : state.members,
         state.members,
       )
       |> React.array}
      {state.loading
         ? <div className=Styles.loading> {React.string("Loading...")} </div>
         : React.null}
    </div>
  </div>;
};
