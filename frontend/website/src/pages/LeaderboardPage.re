module Styles = {
  open Css;
  let page =
    style([
      maxWidth(`rem(81.5)),
      paddingLeft(`rem(1.25)),
      paddingRight(`rem(1.25)),
      margin(`auto),
    ]);

  let header = merge([Theme.H1.basic, style([marginTop(`rem(4.))])]);

  let heroRow =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
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
      position(`relative),
      top(`rem(1.0)),
      media(Theme.MediaQuery.notMobile, [flexDirection(`row)]),
    ]);

  let heroLeft = style([maxWidth(`rem(38.))]);
  let heroRight = style([display(`flex), flexDirection(`column)]);
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

module ToggleButtons = {
  module ButtonStyles = {
    open Css;
    let flexColumn =
      merge([
        Styles.flexColumn,
        style([
          height(`rem(4.5)),
          media("(max-width: 960px)", [display(`none)]),
        ]),
      ]);

    let buttonRow =
      merge([
        Styles.buttonRow,
        style([
          width(`rem(40.5)),
          borderRadius(`px(4)),
          overflow(`hidden),
          selector(
            "*:not(:last-child)",
            [borderRight(`px(1), `solid, Theme.Colors.grey)],
          ),
        ]),
      ]);

    let textStyles =
      merge([Theme.H6.extraSmall, style([textTransform(`uppercase)])]);

    let hover =
      hover([
        backgroundColor(Theme.Colors.hyperlinkHover),
        color(Theme.Colors.white),
        textShadow(~y=`px(1), Theme.Colors.blackAlpha(0.25)),
      ]);

    let button =
      merge([
        textStyles,
        style([
          hover,
          display(`flex),
          justifyContent(`center),
          alignItems(`center),
          width(`rem(13.5)),
          height(`rem(2.5)),
          textAlign(`center),
          backgroundColor(Theme.Colors.gandalf),
          color(Theme.Colors.denimTwo),
          cursor(`pointer),
        ]),
      ]);

    let selectedButton =
      merge([
        button,
        style([
          boxShadow(
            ~blur=`px(8),
            ~inset=true,
            Theme.Colors.blackAlpha(0.1),
          ),
          textShadow(~y=`px(1), Theme.Colors.blackAlpha(0.25)),
          backgroundColor(Theme.Colors.hyperlink),
          color(Theme.Colors.white),
        ]),
      ]);
  };

  [@react.component]
  let make = (~currentOption, ~onTogglePress) => {
    <div className=ButtonStyles.flexColumn>
      <h3 className=Theme.H5.semiBold> {React.string("View")} </h3>
      <Spacer height=0.5 />
      <div className=ButtonStyles.buttonRow>
        <div
          className={
            currentOption == "btn1"
              ? ButtonStyles.selectedButton : ButtonStyles.button
          }
          onClick={_ => onTogglePress("btn1")}>
          {React.string("All Participants")}
        </div>
        <div
          className={
            currentOption == "btn2"
              ? ButtonStyles.selectedButton : ButtonStyles.button
          }
          onClick={_ => onTogglePress("btn2")}>
          {React.string("Genesis Members")}
        </div>
        <div
          className={
            currentOption == "btn3"
              ? ButtonStyles.selectedButton : ButtonStyles.button
          }
          onClick={_ => onTogglePress("btn3")}>
          {React.string("Non-Genesis Members")}
        </div>
      </div>
    </div>;
  };
};

module Moment = {
  type t;
};

[@bs.module] external momentWithDate: Js.Date.t => Moment.t = "moment";
[@bs.send] external format: (Moment.t, string) => string = "format";

type state = {currentOption: string};
let initialState = {currentOption: "btn1"};

type action =
  | Toggled(string);

let reducer = (_, action) => {
  switch (action) {
  | Toggled(option) => {currentOption: option}
  };
};

[@react.component]
let make = (~lastManualUpdatedDate) => {
  let (state, dispatch) = React.useReducer(reducer, initialState);

  let onTogglePress = s => {
    dispatch(Toggled(s));
  };

  let dateAsMoment = momentWithDate(lastManualUpdatedDate);
  let date = format(dateAsMoment, "MMMM Do YYYY");
  <Page title="Testnet Leaderboard">
    <Wrapped>
      <div className=Styles.page>
        <h1 className=Styles.header>
          {React.string("Testnet Leaderboard")}
        </h1>
        <div className=Styles.heroRow>
          <div className=Styles.heroLeft>
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
              <Spacer width=2.0 height=1.0 />
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
                  {React.string("Last manually updated " ++ date)}
                </span>
              </div>
            </div>
          </div>
        </div>
        <div>
          <ToggleButtons currentOption={state.currentOption} onTogglePress />
        </div>
      </div>
    </Wrapped>
  </Page>;
};