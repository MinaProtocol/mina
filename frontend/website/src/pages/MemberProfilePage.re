module Styles = {
  open Css;
  let page =
    style([
      maxWidth(`rem(58.0)),
      margin(`auto),
      media(Theme.MediaQuery.tablet, [maxWidth(`rem(89.))]),
      selector("> :not(:first-child)", [marginTop(`rem(5.))]),
    ]);

  let loading =
    style([
      padding(`rem(5.)),
      color(Theme.Colors.leaderboardMidnight),
      textAlign(`center),
    ]);

  let divider =
    style([
      width(`percent(100.)),
      border(`px(1), `dashed, `hex("C8C8C8")),
    ]);
};

/* Adds the remaining length to the array parameter.
   This is done because the Google Sheets API truncates trailing empty cells.
   */
let normalizeGoogleSheets = (length, a) => {
  let rowLength = Array.length(a);
  if (rowLength < length) {
    Array.append(a, ArrayLabels.make(length - rowLength, ""));
  } else {
    a;
  };
};

let fetchRelease = (name, release) => {
  let (releaseName, range, challengeColumnOffset) = release;
  Sheets.fetchRange(
    ~sheet="1Nq_Y76ALzSVJRhSFZZm4pfuGbPkZs2vTtCnVQ1ehujE",
    ~range,
  )
  |> Promise.map(res => {
       let rows = Array.map(Leaderboard.parseEntry, res);

       let numberOfChallenges =
         rows->Belt.Array.slice(~offset=0, ~len=1)->Array.get(0)
         |> Array.length;

       let challengeTitles =
         rows
         ->Belt.Array.slice(~offset=0, ~len=1)
         ->Array.get(0)
         ->Belt.Array.slice(
             ~offset=challengeColumnOffset,
             ~len=numberOfChallenges,
           );

       let userInfo =
         rows
         ->Belt.Array.keep(entry =>
             String.lowercase_ascii(entry[0]) == String.lowercase_ascii(name)
           )
         ->Array.get(0)
         ->Belt.Array.slice(
             ~offset=challengeColumnOffset,
             ~len=numberOfChallenges,
           )
         |> normalizeGoogleSheets(Array.length(challengeTitles)); /* This is done so we have an equal number of point entries and challenges */

       let challengeInfo =
         userInfo
         |> Belt.Array.zip(challengeTitles)
         |> Array.map(user => {
              let (challengeTitle, challengePoints) = user;
              switch (challengePoints) {
              | "" => {
                  ChallengePointsTable.challengeName: challengeTitle,
                  challengePoints: None,
                }
              | points => {
                  ChallengePointsTable.challengeName: challengeTitle,
                  challengePoints: Some(int_of_string(points)),
                }
              };
            });

       Some({
         ChallengePointsTable.name: releaseName,
         challenges: challengeInfo,
       });
     })
  |> Js.Promise.catch(_ => Promise.return(None));
};

let fetchReleases = name => {
  let releases = [|
    ("Release 3.1", "3.1!B3:Z", 4), /* offset for challenge titles in 3.1 starts on the 4th column */
    ("Release 3.2a", "3.2a!B3:Z", 2), /* offset for challenge titles in 3.2a starts on the 2nd column */
    ("Release 3.2b", "3.2b!B3:Z", 2) /* offset for challenge titles in 3.1 starts on the 2nd column */
  |];
  releases |> Array.map(release => fetchRelease(name, release));
};

type state = {
  loading: bool,
  releases: array(ChallengePointsTable.releaseInfo),
};

let initialState = {loading: true, releases: [||]};

type actions =
  | UpdateReleaseInfo(array(ChallengePointsTable.releaseInfo));

let reducer = (prevState, action) => {
  switch (action) {
  | UpdateReleaseInfo(releases) => {
      loading: false,
      releases: Belt.Array.concat(prevState.releases, releases),
    }
  };
};

[@react.component]
let make = () => {
  let (state, dispatch) = React.useReducer(reducer, initialState);

  /* using a random member from the leaderboards to test table fetching/rendering */
  let testMember = {
    Leaderboard.rank: 1,
    name: "kunkomu#6084",
    phase: 10000,
    release: 5000,
    allTime: 10500,
  };

  let {Leaderboard.name, phase, release, allTime} = testMember;

  React.useEffect0(() => {
    fetchReleases(name)
    |> Array.iter(e => {
         e
         |> Promise.iter(releaseInfo => {
              switch (releaseInfo) {
              | Some(releaseInfo) =>
                dispatch(UpdateReleaseInfo([|releaseInfo|]))
              | None => ()
              }
            })
       });
    None;
  });

  <Page title="Member Profile">
    <Wrapped>
      <div className=Styles.page>
        <div> <ProfileHero name release phase allTime /> </div>
        {state.releases
         |> Array.map((release: ChallengePointsTable.releaseInfo) => {
              <div>
                <ChallengePointsTable
                  releaseTitle={release.name}
                  challengeInfo={release.challenges}
                />
              </div>
            })
         |> React.array}
        {state.loading
           ? <div> {React.string("Loading...")} </div> : React.null}
      </div>
    </Wrapped>
  </Page>;
};
