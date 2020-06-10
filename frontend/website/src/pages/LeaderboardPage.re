module Styles = {
  open Css;
  let page = style([maxWidth(`rem(89.0)), margin(`auto)]);

  let header = merge([Theme.H1.basic, style([marginTop(`rem(4.))])]);

  let heroRow =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`flexStart),
      alignItems(`center),
      media(
        Theme.MediaQuery.tablet,
        [flexDirection(`row), padding2(~v=`rem(3.5), ~h=`zero)],
      ),
    ]);

  let heroH3 =
    merge([
      Theme.H3.basic,
      style([
        textAlign(`left),
        fontWeight(`semiBold),
        color(Theme.Colors.marine),
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
      maxWidth(`rem(38.)),
      marginTop(`rem(2.5)),
      media(Theme.MediaQuery.tablet, [marginTop(`zero)]),
    ]);
  let heroRight =
    style([
      display(`flex),
      flexDirection(`column),
      media(
        Theme.MediaQuery.tablet,
        [minHeight(`rem(21.)), marginLeft(`rem(6.))],
      ),
    ]);
  let flexColumn =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`center),
    ]);

  let heroLinks =
    style([
      media(
        Theme.MediaQuery.notMobile,
        [padding2(~v=`rem(0.), ~h=`rem(6.0))],
      ),
    ]);
  let icon =
    style([marginRight(`px(8)), position(`relative), top(`px(3))]);
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
    let container =
      style([
        display(`flex),
        flexDirection(`row),
        justifyContent(`spaceAround),
        maxWidth(`rem(20.)),
        flexWrap(`wrap),
        media(
          Theme.MediaQuery.notMobile,
          [padding2(~v=`zero, ~h=`rem(2.5)), maxWidth(`rem(35.))],
        ),
      ]);
    let flexColumn =
      style([
        display(`flex),
        flexDirection(`column),
        justifyContent(`center),
      ]);
  };
  [@react.component]
  let make = (~participants="456", ~blocks="123", ~genesisMembers="121") => {
    <div className=Styles.container>
      <div className=Styles.flexColumn>
        <h2 className=Styles.statistic> {React.string("Participants")} </h2>
        <p className=Styles.value> {React.string(participants)} </p>
      </div>
      <div className=Styles.flexColumn>
        <h2 className=Styles.statistic> {React.string("Blocks")} </h2>
        <p className=Styles.value> {React.string(blocks)} </p>
      </div>
      <div className=Styles.flexColumn>
        <h2 className=Styles.statistic>
          {React.string("Genesis Members")}
        </h2>
        <p className=Styles.value> {React.string(genesisMembers)} </p>
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
           "Coda rewards community members with testnet points* for completing challenges \
           that contribute to the development of the protocol.",
         )}
      </p>
      <span className=Theme.Body.basic>
        {React.string(
           "*Testnet Points (abbreviated 'pts') are designed solely to track contributions \
           to the Testnet and Testnet Points have no cash or other monetary value. \
           Testnet Points are not transferable and are not redeemable or exchangeable \
           for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.",
         )}
      </span>
    </div>;
  };
};

module Moment = {
  type t;
};

[@bs.module] external momentWithDate: Js.Date.t => Moment.t = "moment";
[@bs.send] external format: (Moment.t, string) => string = "format";

[@react.component]
let make = (~lastManualUpdatedDate) => {
  let dateAsMoment = momentWithDate(lastManualUpdatedDate);
  let date = format(dateAsMoment, "MMMM Do YYYY");
  <Page title="Testnet Leaderboard">
    <Wrapped>
      <div className=Styles.page>
        <h1 className=Styles.header>
          {React.string("Testnet Leaderboard")}
        </h1>
        <div className=Styles.heroRow>
          <div className=Styles.heroLeft> <StatisticsRow /> <HeroText /> </div>
          <div className=Styles.heroRight>
            <div className=Styles.buttonRow>
              <Button
                link=""
                label="Current Challenges"
                bgColor=Theme.Colors.jungle
                bgColorHover=Theme.Colors.clover
              />
              <Spacer width=2.0 height=1.0 />
              <Button
                link=""
                label="Genesis Program"
                bgColor=Theme.Colors.jungle
                bgColorHover=Theme.Colors.clover
              />
            </div>
            <Spacer height=3.0/>
            <div className=Styles.heroLinks>
              <div className=Styles.flexColumn>
                <Next.Link href="">
                  <a className=Theme.Link.basic>
                    <Svg
                      link="/static/img/Icon.Link.svg"
                      dims=(1.0, 1.0)
                      className=Styles.icon
                      alt="an arrow pointing to the right with a square around it"
                    />
                    {React.string("Leaderboard FAQ")}
                  </a>
                </Next.Link>
                <Next.Link href="">
                  <a className=Theme.Link.basic>
                    <Svg
                      link="/static/img/Icon.Link.svg"
                      dims=(0.9425, 0.8725)
                      className=Styles.icon
                      alt="an arrow pointing to the right with a square around it"
                    />
                    {React.string("Discord #Leaderboard Channel")}
                  </a>
                </Next.Link>
                <span className=Theme.Link.basic>
                  <Svg
                    link="/static/img/Icon.Info.svg"
                    className=Styles.icon
                    dims=(1.0, 1.0)
                    alt="a undercase letter i inside a blue circle"
                  />
                  {React.string("Last manually updated " ++ date)}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Wrapped>
  </Page>;
};