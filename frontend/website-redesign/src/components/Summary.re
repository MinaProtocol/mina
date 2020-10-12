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
  let container =
    style([media(Theme.MediaQuery.tablet, [marginTop(`rem(5.))])]);
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
      padding2(~v=`rem(2.8), ~h=`rem(2.5)),
      media(Theme.MediaQuery.tablet, [padding2(~v=`zero, ~h=`zero)]),
      media(
        Theme.MediaQuery.desktop,
        [flexDirection(`row), paddingTop(`zero)],
      ),
    ]);

  let heroH3 =
    merge([
      Theme.Type.paragraphSmall,
      style([
        textAlign(`left),
        fontWeight(`normal),
        color(Theme.Colors.black),
        marginTop(`rem(4.)),
        media(
          Theme.MediaQuery.notMobile,
          [marginTop(`rem(3.5)), marginBottom(`rem(1.5))],
        ),
      ]),
    ]);

  let disclaimer =
    merge([
      Theme.Type.paragraph,
      style([
        marginTop(`rem(3.6)),
        fontSize(`rem(1.)),
        color(Theme.Colors.greyScale),
        media(
          Theme.MediaQuery.notMobile,
          [
            display(`inline),
            marginTop(`rem(4.6)),
            marginBottom(`rem(4.6)),
            lineHeight(`rem(1.)),
          ],
        ),
      ]),
    ]);
  let buttonRow =
    style([
      display(`flex),
      flexDirection(`column),
      marginTop(`rem(4.)),
      media(
        Theme.MediaQuery.tablet,
        [flexDirection(`row), justifyContent(`flexStart)],
      ),
    ]);

  let heroLeft =
    style([
      media(
        Theme.MediaQuery.tablet,
        [width(`rem(39.)), marginTop(`rem(4.)), marginRight(`rem(6.))],
      ),
    ]);
  let heroRight =
    style([
      display(`flex),
      position(`relative),
      top(`zero),
      flexDirection(`column),
      width(`rem(40.)),
      media(Theme.MediaQuery.tablet, [marginTop(`rem(4.))]),
      media(Theme.MediaQuery.desktop, [marginTop(`zero)]),
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
        [position(`absolute), top(`rem(10.)), left(`zero)],
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

    let container = style([display(`flex), justifyContent(`spaceBetween)]);

    let flexColumn =
      style([
        display(`flex),
        flexDirection(`column),
        justifyContent(`flexStart),
      ]);

    let h2 =
      style([
        Theme.Typeface.monumentGrotesk,
        fontWeight(`normal),
        fontSize(`rem(2.5)),
        lineHeight(`rem(3.)),
        color(Theme.Colors.digitalBlack),
      ]);

    let label =
      style([
        Theme.Typeface.monumentGroteskMono,
        textTransform(`uppercase),
        fontSize(`rem(0.875)),
        lineHeight(`rem(1.)),
        color(Theme.Colors.digitalBlack),
      ]);
  };
  [@react.component]
  let make = (~statistics) => {
    <div className=Styles.container>
      <div className=Styles.flexColumn>
        <h2 className=Styles.h2> {React.string(statistics.participants)} </h2>
        <p className=Styles.label> {React.string("Participants")} </p>
      </div>
      <div className=Styles.flexColumn>
        <h2 className=Styles.h2>
          {React.string(statistics.genesisMembers)}
        </h2>
        <p className=Styles.label> {React.string("Genesis Members")} </p>
      </div>
      <div className=Styles.flexColumn>
        <h2 className=Styles.h2> {React.string(statistics.blockCount)} </h2>
        <p className=Styles.label> {React.string("Blocks Produced")} </p>
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
            href={`External("https://bit.ly/3dNmPle")}
            bgColor=Theme.Colors.black
            width={`rem(15.)}
            paddingX=1.5>
            <p className=Theme.Type.buttonLabel>
              {React.string("Current Challenges")}
            </p>
            <Icon kind=Icon.ArrowRightMedium />
          </Button>
          <Spacer width=2.0 height=1.0 />
          <Button
            href={`Internal("/genesis")}
            bgColor=Theme.Colors.black
            width={`rem(13.)}
            paddingX=1.5>
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
