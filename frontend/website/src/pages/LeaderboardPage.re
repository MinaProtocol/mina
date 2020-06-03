module Styles = {
  open Css;
  let page =
    style([
      maxWidth(`rem(81.5)),
      paddingLeft(`rem(1.25)),
      paddingRight(`rem(1.25)),
      margin(`auto),
    ]);

  let heroRow =
    style([
      display(`flex),
      marginTop(`rem(6.15)),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      alignItems(`center),
      media(Theme.MediaQuery.tablet, [flexDirection(`row)]),
    ]);

  let header =
    style([
      display(`flex),
      flexDirection(`column),
      width(`percent(100.)),
      color(Theme.Colors.slate),
      textAlign(`center),
      margin2(~v=rem(3.5), ~h=`zero),
    ]);

  let heroText =
    merge([header, style([maxWidth(`px(500)), textAlign(`left)])]);

  let buttonRow = style([display(`flex), flexDirection(`row)]);
};

module StatisticsRow = {
  module Styles = {
    open Css;
    let statistic =
      style([
        Theme.Typeface.ibmplexsans,
        textTransform(`uppercase),
        fontSize(`rem(1.0)),
        color(Theme.Colors.saville),
        letterSpacing(`px(2)),
        fontWeight(`semiBold),
      ]);

    let value =
      merge([
        statistic,
        style([
          fontSize(`rem(2.25)),
          marginTop(`px(10)),
          textAlign(`center),
        ]),
      ]);
    let flexRow =
      style([
        display(`flex),
        flexDirection(`row),
        justifyContent(`spaceBetween),
      ]);
    let flexColumn =
      style([
        display(`flex),
        flexDirection(`column),
        justifyContent(`center),
      ]);
  };
  [@react.component]
  let make = () => {
    <div className=Styles.flexRow>
      <div className=Styles.flexColumn>
        <h1 className=Styles.statistic> {React.string("Participants")} </h1>
        <p className=Styles.value> {React.string("456")} </p>
      </div>
      <div className=Styles.flexColumn>
        <h1 className=Styles.statistic> {React.string("Blocks")} </h1>
        <p className=Styles.value> {React.string("123")} </p>
      </div>
      <div className=Styles.flexColumn>
        <h1 className=Styles.statistic>
          {React.string("Genesis Members")}
        </h1>
        <p className=Styles.value> {React.string("121")} </p>
      </div>
    </div>;
  };
};

module HeroText = {
  [@react.component]
  let make = () => {
    <div> <p /> <p /> </div>;
  };
};

[@react.component]
let make = () => {
  <Page title="Testnet Leaderboard">
    <Wrapped>
      <div className=Styles.page>
        <div className=Styles.heroRow>
          <div>
            <h1 className=Theme.H1.basic>
              {React.string("Testnet Leaderboard")}
            </h1>
            <Spacer height=4.3 />
            <StatisticsRow />
            <HeroText />
          </div>
          <div className=Styles.buttonRow>
            <Button
              link=""
              label="Current Challenges"
              bgColor=Theme.Colors.jungle
              bgColorHover=Theme.Colors.clover
            />
            <Spacer width=2.0 />
            <Button
              link=""
              label="Genesis Program"
              bgColor=Theme.Colors.jungle
              bgColorHover=Theme.Colors.clover
            />
          </div>
        </div>
      </div>
    </Wrapped>
  </Page>;
};