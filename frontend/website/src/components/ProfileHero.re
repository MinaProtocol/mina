module Styles = {
  open Css;
  let linkRow =
    style([
      media(Theme.MediaQuery.veryVeryLarge, [marginTop(`rem(4.8))]),
    ]);
  let header =
    merge([
      Theme.H1.basic,
      style([
        fontSize(`rem(1.5)),
        lineHeight(`rem(2.)),
        marginBottom(`rem(0.)),
        media(Theme.MediaQuery.notMobile, [fontSize(`rem(3.))]),
      ]),
    ]);
  let links =
    merge([
      Theme.Link.basic,
      style([fontSize(`rem(1.5)), color(Theme.Colors.saville)]),
    ]);
  let icon =
    style([
      margin2(~v=`zero, ~h=`px(4)),
      position(`relative),
      top(`px(1)),
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
        [paddingLeft(`zero), marginBottom(`rem(3.)), alignItems(`center)],
      ),
    ]);
  let link = merge([Theme.Link.basic, style([lineHeight(`px(28))])]);
  let participantDetails =
    merge([
      link,
      style([
        display(`none),
        media(
          Theme.MediaQuery.notMobile,
          [display(`inlineBlock), color(Theme.Colors.saville)],
        ),
      ]),
    ]);

  let flexColumn = style([display(`flex), flexDirection(`column)]);
  let middleRow =
    style([
      display(`flex),
      flexDirection(`row),
      media(
        Theme.MediaQuery.veryVeryLarge,
        [selector(":last-child", [marginLeft(`rem(10.))])],
      ),
    ]);
  let linksColumn = merge([flexColumn, style([marginLeft(`rem(10.))])]);
};

module Links = {
  [@react.component]
  let make = () => {
    <div className=Styles.linksColumn>
      <Button
        link=""
        label="Current Challenges"
        bgColor=Theme.Colors.clover
        bgColorHover=Theme.Colors.jungle
      />
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
    </div>;
  };
};

module Points = {
  module Styles = {
    open Css;
    let flexColumn = style([display(`flex), flexDirection(`column)]);
    let flexRow = style([display(`flex), flexDirection(`row)]);
    let linkRow = merge([flexRow, style([marginBottom(`rem(4.75))])]);
    let pointType =
      merge([
        Theme.H4.header,
        style([position(`relative), top(`px(5)), left(`px(10))]),
      ]);
    let rank =
      merge([Theme.H6.extraSmall, style([textTransform(`uppercase)])]);
    let points = merge([flexColumn, style([marginLeft(`rem(2.))])]);
  };

  module PointsColumn = {
    [@react.component]
    let make = (~pointType, ~rank, ~points) => {
      <div className=Styles.flexColumn>
        <p className=Styles.pointType> {React.string(pointType)} </p>
        <div className=Styles.linkRow>
          <span className=Styles.flexColumn>
            <span className=Styles.rank> {React.string("Rank")} </span>
            <span> {React.string(rank)} </span>
          </span>
          <div className=Styles.points>
            <span> {React.string("Points *")} </span>
            <span> {React.string(points)} </span>
          </div>
        </div>
      </div>;
    };
  };

  [@react.component]
  let make =
      (
        ~pointsForRelease="1000",
        ~pointsforPhase="11000",
        ~pointsAllTime="100000",
      ) => {
    <div className=Styles.flexRow>
      <PointsColumn pointType="This Release" rank="1" points="5000" />
      <PointsColumn pointType="This Phase" rank="19" points="10000" />
      <PointsColumn pointType="All Time" rank="101" points="10500" />
    </div>;
  };
};

[@react.component]
let make = (~name="Matt Harrott / Figment Network#8705") => {
  <div className=Styles.linkRow>
    <Next.Link href="/testnet">
      <a className=Theme.Link.basic> {React.string("Testnet")} </a>
    </Next.Link>
    <span className=Styles.icon> Icons.rightCarrot </span>
    <Next.Link href="/leaderboard">
      <a className=Theme.Link.basic> {React.string("Leaderboard")} </a>
    </Next.Link>
    <span className=Styles.icon> Icons.rightCarrot </span>
    <span className=Styles.participantDetails>
      {React.string("Participant Details")}
    </span>
    <p className=Styles.header> {React.string(name)} </p>
    <div className=Styles.middleRow> <Points /> <Links /> </div>
  </div>;
};