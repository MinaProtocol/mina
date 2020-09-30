module Moment = {
  type t;
};

[@bs.module] external momentWithDate: Js.Date.t => Moment.t = "moment";
[@bs.send] external format: (Moment.t, string) => string = "format";

type statistics = {
  genesisMembers: string,
  blockCount: string,
  participants: string,
  date: string,
};

let fetchStatistics = () => {
  Sheets.fetchRange(
    ~sheet="1Nq_Y76ALzSVJRhSFZZm4pfuGbPkZs2vTtCnVQ1ehujE",
    ~range="Data!A2:D",
  )
  |> Promise.bind(res => {
       let entry = Leaderboard.parseEntry(res[0]);
       {
         genesisMembers: entry |> Leaderboard.safeArrayGet(0),
         blockCount: entry |> Leaderboard.safeArrayGet(1),
         participants: entry |> Leaderboard.safeArrayGet(2),
         date: entry |> Leaderboard.safeArrayGet(3),
       }
       ->Some
       ->Promise.return;
     })
  |> Js.Promise.catch(_ => Promise.return(None));
};

module Styles = {
  open Css;
  let container = style([marginTop(`rem(5.))]);
  let header =
    merge([
      Theme.Type.h1,
      style([
        marginTop(`zero),
        fontSize(`rem(3.)),
        lineHeight(`rem(4.)),
        media(Theme.MediaQuery.notMobile, [marginTop(`rem(4.))]),
      ]),
    ]);

  let heroRow =
    style([
      display(`flex),
      flexDirection(`column),
      paddingTop(`rem(2.8)),
      media(
        Theme.MediaQuery.desktop,
        [flexDirection(`row), paddingTop(`zero), marginTop(`rem(3.5))],
      ),
    ]);

  let heroH3 =
    merge([
      Theme.Type.paragraphSmall,
      style([
        display(none),
        textAlign(`left),
        fontWeight(`normal),
        color(Theme.Colors.black),
        media(
          Theme.MediaQuery.notMobile,
          [
            display(`block),
            marginTop(`rem(3.5)),
            marginBottom(`rem(1.5)),
          ],
        ),
      ]),
    ]);

  let disclaimer =
    merge([
      Theme.Type.paragraphSmall,
      style([
        marginTop(`rem(3.6)),
        color(Theme.Colors.greyScale),
        media(
          Theme.MediaQuery.notMobile,
          [
            display(`inline),
            marginTop(`rem(4.6)),
            important(fontSize(`px(13))),
            lineHeight(`rem(1.)),
          ],
        ),
      ]),
    ]);
  let buttonRow =
    style([
      display(`flex),
      flexDirection(`column),
      marginTop(`rem(3.)),
      media(
        Theme.MediaQuery.notMobile,
        [flexDirection(`row), justifyContent(`flexStart)],
      ),
      media(Theme.MediaQuery.tablet, [marginTop(`zero)]),
    ]);

  let heroLeft =
    style([
      media(Theme.MediaQuery.tablet, [marginBottom(`rem(3.))]),
      media(
        Theme.MediaQuery.desktop,
        [maxWidth(`rem(38.)), marginRight(`rem(7.))],
      ),
    ]);
  let heroRight =
    style([
      display(`flex),
      position(`relative),
      top(`zero),
      flexDirection(`column),
      paddingLeft(`rem(1.)),
      alignItems(`center),
      unsafe("width", "fit-content"),
      media(
        Theme.MediaQuery.tablet,
        [paddingLeft(`zero), marginBottom(`rem(8.)), alignItems(`center)],
      ),
    ]);
  let flexColumn =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`flexStart),
    ]);

  let heroLinks =
    style([
      media(
        Theme.MediaQuery.notMobile,
        [position(`absolute), top(`rem(7.)), left(`zero)],
      ),
    ]);

  let link =
    merge([
      Theme.Type.link,
      style([lineHeight(`px(28)), color(Theme.Colors.orange)]),
    ]);
  let updatedDate =
    merge([
      Theme.Type.h6,
      style([color(Theme.Colors.black), marginTop(`px(12))]),
    ]);
  let icon =
    style([marginRight(`px(8)), position(`relative), top(`px(1))]);
};

module StatisticsRow = {
  module Styles = {
    open Css;
    let statistic =
      style([
        Theme.Typeface.monumentGroteskMono,
        textTransform(`uppercase),
        fontSize(`px(14)),
        color(Theme.Colors.black),
        letterSpacing(`em(0.03)),
      ]);

    let value =
      merge([
        statistic,
        style([
          display(`flex),
          media(
            Theme.MediaQuery.tablet,
            [
              marginBottom(`px(3)),
              fontSize(`rem(2.5)),
              lineHeight(`rem(2.5)),
            ],
          ),
        ]),
      ]);
    let container =
      style([
        display(`flex),
        flexWrap(`wrap),
        justifyContent(`spaceBetween),
        media(
          Theme.MediaQuery.tablet,
          [gridTemplateColumns([`rem(12.), `rem(12.), `rem(12.)])],
        ),
      ]);
    let flexColumn =
      style([
        display(`flex),
        flexDirection(`column),
        justifyContent(`flexStart),
      ]);
    let lastStatistic =
      merge([
        flexColumn,
        style([
          marginTop(`rem(1.)),
          media("(min-width: 26.8rem)", [marginTop(`zero)]),
        ]),
      ]);
  };
  [@react.component]
  let make = (~statistics) => {
    <div className=Styles.container>
      <div className=Styles.flexColumn>
        <div className=Styles.value>
          {React.string(statistics.participants)}
        </div>
        <h2 className=Styles.statistic> {React.string("Participants")} </h2>
      </div>
      <div className=Styles.flexColumn>
        <span className=Styles.value>
          {React.string(statistics.genesisMembers)}
        </span>
        <span className=Styles.statistic>
          {React.string("Genesis Members")}
        </span>
      </div>
      <div className=Styles.lastStatistic>
        <div className=Styles.value>
          {React.string(statistics.blockCount)}
        </div>
        <h2 className=Styles.statistic>
          {React.string("Blocks Produced")}
        </h2>
      </div>
    </div>;
  };
};

module HeroText = {
  [@react.component]
  let make = () => {
    <div>
      <p className=Styles.heroH3>
        {React.string(
           "Mina rewards community members with testnet points for completing challenges that contribute to the development of the protocol.* ",
         )}
      </p>
      <div className=Styles.disclaimer>
        {React.string(
           "*Testnet Points (abbreviated 'pts') are designed solely to track contributions \
           to the Testnet and Testnet Points have no cash or other monetary value. \
           Testnet Points are not transferable and are not redeemable or exchangeable \
           for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.",
         )}
      </div>
    </div>;
  };
};

type state = {statistics: option(statistics)};
let initialState = {statistics: None};

type actions =
  | UpdateStatistics(statistics);

let reducer = (_, action) => {
  switch (action) {
  | UpdateStatistics(statistics) => {statistics: Some(statistics)}
  };
};

[@react.component]
let make = () => {
  let (state, dispatch) = React.useReducer(reducer, initialState);

  React.useEffect0(() => {
    fetchStatistics()
    |> Promise.iter(e =>
         Belt.Option.mapWithDefault(e, (), statistics =>
           dispatch(UpdateStatistics(statistics))
         )
       );
    None;
  });

  <div className=Styles.container>
    <h1 className=Styles.header> {React.string("Testnet Leaderboard")} </h1>
    <div className=Styles.heroRow>
      <div className=Styles.heroLeft>
        {switch (state.statistics) {
         | Some(statistics) => <StatisticsRow statistics />
         | None => React.null
         }}
        <HeroText />
      </div>
      <div className=Styles.heroRight>
        <div className=Styles.buttonRow>
          <Button
            href=`External("https://bit.ly/3dNmPle")
            bgColor=Theme.Colors.black
            width={`rem(15.)}
            paddingX=1.5>
            <p className=Theme.Type.buttonLabel>
              {React.string("Current Challenges")}
            </p>
            <Icon kind=Icon.ArrowRightMedium />
          </Button>
          <Spacer width=2.0 height=1.0 />
          <Button href=`Internal("/genesis") bgColor=Theme.Colors.black width={`rem(13.)} paddingX=1.5>
            <p className=Theme.Type.buttonLabel>
              {React.string("Genesis Program")}
            </p>
            <Icon kind=Icon.ArrowRightMedium />
          </Button>
        </div>
        <Spacer height=4.8 />
        <div className=Styles.heroLinks>
          <div className=Styles.flexColumn>
            <Next.Link href="https://bit.ly/leaderboardFAQ">
              <a className=Styles.link>
                {React.string("Leaderboard FAQ")}
                <Icon kind=Icon.Digital />
              </a>
            </Next.Link>
            <Next.Link href="https://bit.ly/MinaDiscord">
              <a className=Styles.link>
                {React.string("Discord #Leaderboard Channel")}
                <Icon kind=Icon.Digital />
              </a>
            </Next.Link>
            <span className=Styles.updatedDate>
              {switch (state.statistics) {
               | Some(statistics) =>
                 let date =
                   statistics.date
                   ->Js.Date.fromString
                   ->momentWithDate
                   ->format("MMMM Do YYYY");
                 React.string("Last manual update " ++ date);
               | None => React.null
               }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>;
};
