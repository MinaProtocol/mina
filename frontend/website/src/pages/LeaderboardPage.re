module Styles = {
  open Css;
  let page = style([maxWidth(`rem(89.0)), margin(`auto)]);

  let header =
    merge([
      Theme.H1.basic,
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
      justifyContent(`flexStart),
      alignItems(`center),
      paddingTop(`rem(2.8)),
      media(
        Theme.MediaQuery.tablet,
        [
          flexDirection(`row),
          padding2(~v=`rem(3.5), ~h=`zero),
          paddingTop(`zero),
        ],
      ),
    ]);

  let heroH3 =
    merge([
      Theme.H3.basic,
      style([
        display(none),
        media(Theme.MediaQuery.notMobile, [display(`block)]),
        textAlign(`left),
        fontWeight(`semiBold),
        color(Theme.Colors.marine),
      ]),
    ]);

  let asterisk =
    merge([
      Theme.Body.basic,
      style([
        display(none),
        media(Theme.MediaQuery.notMobile, [display(`inline)]),
      ]),
    ]);
  let disclaimer =
    merge([Theme.Body.basic_small, style([marginTop(`rem(4.6))])]);
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
      media(Theme.MediaQuery.tablet, [marginTop(`zero)]),
    ]);
  let heroRight =
    style([
      display(`flex),
      flexDirection(`column),
      paddingLeft(`rem(1.)),
      alignItems(`flexStart),
      media(
        Theme.MediaQuery.tablet,
        [minHeight(`rem(21.)), marginLeft(`rem(6.)), paddingLeft(`zero)],
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

  let link = merge([Theme.Link.basic, style([lineHeight(`px(28))])]);
  let coloredLink = merge([link, style([color(Theme.Colors.teal)])]);
  let icon =
    style([marginRight(`px(8)), position(`relative), top(`px(1))]);
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
        style([fontSize(`rem(2.25)), textAlign(`center)]),
      ]);
    let container =
      style([
        display(`flex),
        flexDirection(`row),
        justifyContent(`spaceAround),
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
    let lastStatistic =
      merge([flexColumn, style([marginTop(`rem(2.25))])]);
  };
  [@react.component]
  let make = (~participants="456", ~blocks="123", ~genesisMembers="121") => {
    <div className=Styles.container>
      <div className=Styles.flexColumn>
        <h2 className=Styles.statistic> {React.string("Participants")} </h2>
        <span className=Styles.value> {React.string(participants)} </span>
      </div>
      <div className=Styles.flexColumn>
        <h2 className=Styles.statistic> {React.string("Blocks")} </h2>
        <span className=Styles.value> {React.string(blocks)} </span>
      </div>
      <div className=Styles.lastStatistic>
        <span className=Styles.statistic>
          {React.string("Genesis Members")}
        </span>
        <span className=Styles.value> {React.string(genesisMembers)} </span>
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
      <span className=Styles.asterisk> {React.string("*")} </span>
      <div className=Styles.disclaimer>
        {React.string(
           "Testnet Points (abbreviated 'pts') are designed solely to track contributions \
           to the Testnet and Testnet Points have no cash or other monetary value. \
           Testnet Points are not transferable and are not redeemable or exchangeable \
           for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.",
         )}
      </div>
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
            <Spacer height=3.0 />
            <div className=Styles.heroLinks>
              <div className=Styles.flexColumn>
                <Next.Link href="">
                  <a className=Styles.link>
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
                  <a className=Styles.link>
                    <Svg
                      link="/static/img/Icon.Link.svg"
                      dims=(0.9425, 0.8725)
                      className=Styles.icon
                      alt="an arrow pointing to the right with a square around it"
                    />
                    {React.string("Discord #Leaderboard Channel")}
                  </a>
                </Next.Link>
                <span className=Styles.coloredLink>
                  <Svg
                    link="/static/img/Icon.Info.svg"
                    className=Styles.icon
                    dims=(1.0, 1.0)
                    alt="a undercase letter i inside a blue circle"
                  />
                  {React.string("Last manual update " ++ date)}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Wrapped>
  </Page>;
};