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

module Toggle = {
  type t =
    | All
    | Genesis
    | NonGenesis;

  let toggles = [|All, Genesis, NonGenesis|];

  let toggle_of_string = toggle => {
    switch (toggle) {
    | "All Participants" => All
    | "Genesis Members" => Genesis
    | "Non-Genesis Members" => NonGenesis
    | _ => All
    };
  };

  let string_of_toggle = toggle => {
    switch (toggle) {
    | All => "All Participants"
    | Genesis => "Genesis Members"
    | NonGenesis => "Non-Genesis Members"
    };
  };
};

module Filter = {
  type t =
    | Release
    | Phase
    | AllTime;

  let string_of_filter = filter => {
    switch (filter) {
    | Release => "This Release"
    | Phase => "This Phase"
    | AllTime => "All Time"
    };
  };

  let filter_of_string = filter => {
    switch (filter) {
    | "This Release" => Release
    | "This Phase" => Phase
    | "All Time" => AllTime
    | _ => AllTime
    };
  };

  let filters = [|Release, Phase, AllTime|];
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
        [
          backgroundColor(`rgba((245, 245, 245, 1.))),
          hover([backgroundColor(`hex("E0E0E0"))]),
        ],
      ),
    ]);

  let desktopLeaderboardRow =
    style([
      cursor(`pointer),
      padding2(~v=`rem(1.), ~h=`rem(1.)),
      height(`rem(3.5)),
      display(`grid),
      gridColumnGap(rem(1.5)),
      gridTemplateColumns([
        rem(1.),
        rem(5.5),
        rem(5.5),
        rem(3.5),
        rem(3.5),
      ]),
      hover([backgroundColor(`hex("E0E0E0"))]),
      media(
        Theme.MediaQuery.tablet,
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
      desktopLeaderboardRow,
      style([
        display(`none),
        paddingBottom(`rem(0.5)),
        fontSize(`rem(1.)),
        fontWeight(`semiBold),
        textTransform(`uppercase),
        letterSpacing(`rem(0.125)),
        media(Theme.MediaQuery.notMobile, [display(`grid)]),
        hover([backgroundColor(white)]),
      ]),
    ]);

  let activeColumn =
    style([
      position(`relative),
      justifySelf(`flexEnd),
      after([
        position(`absolute),
        left(`percent(100.)),
        contentRule(""),
        height(`rem(1.5)),
        width(`rem(1.5)),
        backgroundImage(`url("/static/img/arrowDown.svg")),
        backgroundRepeat(`noRepeat),
        backgroundPosition(`px(4), `px(9)),
      ]),
    ]);

  let inactiveColumn =
    style([
      display(`none),
      justifySelf(`flexEnd),
      media(Theme.MediaQuery.tablet, [display(`inline)]),
    ]);

  let topTen = style([position(`absolute)]);

  let cell =
    style([height(`rem(2.)), whiteSpace(`nowrap), overflowX(`hidden)]);
  let flexEnd = style([justifySelf(`flexEnd)]);
  let rank = merge([cell, flexEnd]);
  let username =
    merge([cell, style([textOverflow(`ellipsis), fontWeight(`semiBold)])]);
  let pointsCell = merge([cell, style([justifySelf(`flexEnd)])]);
  let activePointsCell =
    merge([cell, style([justifySelf(`flexEnd), fontWeight(`semiBold)])]);
  let inactivePointsCell =
    merge([
      pointsCell,
      style([
        media(Theme.MediaQuery.tablet, [display(`inline)]),
        display(`none),
        opacity(0.5),
      ]),
    ]);

  let loading =
    style([
      padding(`rem(5.)),
      color(Theme.Colors.leaderboardMidnight),
      textAlign(`center),
    ]);

  let desktopLayout =
    style([
      display(`none),
      media(Theme.MediaQuery.notMobile, [display(`unset)]),
    ]);

  let mobileLayout =
    style([
      display(`unset),
      media(Theme.MediaQuery.notMobile, [display(`none)]),
    ]);

  let mobileLeaderboardRow =
    style([
      display(`grid),
      gridTemplateColumns([rem(5.), `auto]),
      gridColumnGap(rem(1.5)),
      cursor(`pointer),
      padding2(~v=`rem(1.), ~h=`rem(1.)),
      fontWeight(`semiBold),
      fontSize(`px(16)),
      lineHeight(`px(24)),
    ]);

  let firstColumn = style([textAlign(`right), color(`hex("757575"))]);

  let mobilePointStar =
    merge([
      firstColumn,
      style([
        before([
          contentRule("*"),
          color(Css_Colors.red),
          marginRight(`rem(0.5)),
        ]),
      ]),
    ]);
};

module LeaderboardRow = {
  open Filter;
  let getRank = (sort, member) => {
    switch (sort) {
    | Phase => member.phaseRank
    | Release => member.releaseRank
    | AllTime => member.allTimeRank
    };
  };

  let getPoints = (column, member) =>
    switch (column) {
    | Phase => member.phasePoints
    | Release => member.releasePoints
    | AllTime => member.allTimePoints
    };

  let renderPoints = (sort, column, member) => {
    <span
      key={member.name ++ string_of_filter(column)}
      className=Styles.(
        sort === column ? activePointsCell : inactivePointsCell
      )>
      {React.string(string_of_int(getPoints(column, member)))}
    </span>;
  };

  let getUserSlug = member => {
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
  };

  module DesktopLayout = {
    [@react.component]
    let make = (~sort, ~rank, ~member) => {
      //<Next.Link href=""_as=userSlug>
      <div className=Styles.desktopLeaderboardRow>

          <span className=Styles.rank>
            {React.string(string_of_int(rank))}
          </span>
          <span className=Styles.username> {React.string(member.name)} </span>
          {Array.map(column => {renderPoints(sort, column, member)}, filters)
           |> React.array}
        </div>;
        // </Next.Link>;
    };
  };

  module MobileLayout = {
    [@react.component]
    let make = (~sort, ~rank, ~member) => {
      //<Next.Link href=""_as=userSlug>
      <div className=Styles.mobileLeaderboardRow>

          <span className=Styles.firstColumn> {React.string("Rank")} </span>
          <span> {React.string("#" ++ string_of_int(rank))} </span>
          <span className=Styles.firstColumn> {React.string("Name")} </span>
          <span> {React.string(member.name)} </span>
          <span className=Styles.mobilePointStar>
            {React.string("Points")}
          </span>
          <span>
            {React.string(string_of_int(getPoints(sort, member)))}
          </span>
        </div>;
        //</Next.Link>;
    };
  };

  [@react.component]
  let make = (~sort, ~member) => {
    let _userSlug = getUserSlug(member);
    let rank = getRank(sort, member);

    <div>
      <div className=Styles.desktopLayout>
        <DesktopLayout sort rank member />
      </div>
      <div className=Styles.mobileLayout>
        <MobileLayout sort rank member />
      </div>
    </div>;
  };
};

type state = {
  loading: bool,
  members: array(member),
};

type actions =
  | UpdateMembers(array(member));

let reducer = (_, action) => {
  switch (action) {
  | UpdateMembers(members) => {loading: false, members}
  };
};

[@react.component]
let make =
    (
      ~filter: Filter.t=Release,
      ~toggle: Toggle.t=All,
      ~search: string="",
      ~onFilterPress: string => unit=?,
    ) => {
  open Toggle;
  open Filter;
  let initialState = {loading: true, members: [||]};
  let (state, dispatch) = React.useReducer(reducer, initialState);

  React.useEffect0(() => {
    fetchLeaderboard() |> Promise.iter(e => dispatch(UpdateMembers(e)));
    None;
  });

  let sortRank = member =>
    switch (filter) {
    | Phase => member.phaseRank
    | Release => member.releaseRank
    | AllTime => member.allTimeRank
    };

  Array.sort((a, b) => sortRank(a) - sortRank(b), state.members);

  let filteredMembers =
    Js.Array.filter(
      member =>
        switch (toggle) {
        | All => true
        | Genesis => member.genesisMember
        | NonGenesis => !member.genesisMember
        },
      state.members,
    )
    |> Js.Array.filter(member =>
         search === "" ? true : Js.String.includes(search, member.name)
       )
    |> Js.Array.filter(member => sortRank(member) !== 0);

  let renderRow = member =>
    <LeaderboardRow key={member.name} sort=filter member />;

  let renderColumnHeader = column =>
    <span
      key={Filter.string_of_filter(column)}
      onClick={_ => {onFilterPress(string_of_filter(column))}}
      className={
        column === filter ? Styles.activeColumn : Styles.inactiveColumn
      }>
      {React.string(string_of_filter(column))}
    </span>;

  <div className=Styles.leaderboardContainer>
    <div id="testnet-leaderboard" className=Styles.leaderboard>
      <div className=Styles.headerRow>
        <span className=Styles.flexEnd> {React.string("Rank")} </span>
        <span> {React.string("Name")} </span>
        {Array.map(renderColumnHeader, Filter.filters) |> React.array}
      </div>
      <hr />
      <div className=Styles.topTen />
      {state.loading
         ? <div className=Styles.loading> {React.string("Loading...")} </div>
         : Array.map(renderRow, filteredMembers) |> React.array}
    </div>
  </div>;
};
