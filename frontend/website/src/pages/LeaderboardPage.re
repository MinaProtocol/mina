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
      media(
        Theme.MediaQuery.tablet,
        [flexDirection(`row), padding2(~v=`rem(3.5), ~h=`zero)],
      ),
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
      flexDirection(`row),
      position(`relative),
      top(`rem(1.0)),
    ]);

  let heroLeft = style([maxWidth(`rem(38.))]);
  let heroRight = style([display(`flex), flexDirection(`column)]);
  let flexColumn =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`center),
    ]);

  let heroLinks = style([padding2(~v=`rem(0.), ~h=`rem(6.0))]);
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
  let make = (~participants="456", ~blocks="123", ~genesisMembers="121") => {
    <div className=Styles.flexRow>
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
      <p className=Theme.Body.basic>
        {React.string(
           "*Testnet Points (abbreviated 'pts') are designed solely to track contributions \
           to the Testnet and Testnet Points have no cash or other monetary value. \
           Testnet Points are not transferable and are not redeemable or exchangeable \
           for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.",
         )}
      </p>
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
        <div className=Styles.heroRow>
          <div className=Styles.heroLeft>
            <h1 className=Theme.H1.basic>
              {React.string("Testnet Leaderboard")}
            </h1>
            <Spacer height=4.3 />
            <StatisticsRow />
            <HeroText />
          </div>
          <div className=Styles.heroRight>
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
            <Spacer height=4.8 />
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
                  {React.string("Last manually updated ")
                   ++ React.string(date)}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Wrapped>
  </Page>;
};