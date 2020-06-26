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
      flexDirection(`column),
      media(
        Theme.MediaQuery.notMobile,
        [justifyContent(`spaceBetween), marginTop(`rem(5.))],
      ),
      media(
        Theme.MediaQuery.veryVeryLarge,
        [flexDirection(`row), marginTop(`rem(4.8)), width(`rem(75.))],
      ),
    ]);
  let buttonAndLinks =
    merge([
      flexColumn,
      style([
        marginTop(`rem(3.)),
        justifyContent(`spaceBetween),
        media(
          Theme.MediaQuery.notMobile,
          [
            marginLeft(`auto),
            marginRight(`auto),
            marginTop(`rem(5.25)),
            flexDirection(`row),
            width(`rem(35.)),
          ],
        ),
        media(
          Theme.MediaQuery.veryVeryLarge,
          [
            flexDirection(`column),
            marginLeft(`zero),
            marginRight(`zero),
            marginTop(`zero),
          ],
        ),
      ]),
    ]);
  let linksColumn = merge([flexColumn, style([])]);
};

module Links = {
  [@react.component]
  let make = () => {
    <div className=Styles.buttonAndLinks>
      <Button
        link=""
        label="Current Challenges"
        bgColor=Theme.Colors.clover
        bgColorHover=Theme.Colors.jungle
      />
      <Spacer height=1. />
      <div className=Styles.linksColumn>
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
      </div>
    </div>;
  };
};

module Points = {
  module Styles = {
    open Css;
    let pointsColumn = style([display(`flex), flexDirection(`column)]);
    let flexColumn = pointsColumn;
    let rankAndPoints =
      style([
        display(`flex),
        flexDirection(`row),
        marginTop(`rem(1.3)),
        justifyContent(`spaceBetween),
        width(`rem(12.5)),
      ]);

    let pointsRow =
      style([
        display(`flex),
        flexDirection(`row),
        justifyContent(`center),
        selector(
          "> :last-child",
          [
            display(`none),
            media(Theme.MediaQuery.notMobile, [display(`inlineBlock)]),
          ],
        ),
        selector(
          "> :first-child",
          [
            display(`none),
            media(Theme.MediaQuery.notMobile, [display(`inlineBlock)]),
          ],
        ),
        media(
          Theme.MediaQuery.notMobile,
          [width(`rem(51.)), justifyContent(`spaceBetween)],
        ),
        media(
          Theme.MediaQuery.veryVeryLarge,
          [width(`rem(46.5)), justifyContent(`spaceBetween)],
        ),
      ]);
    let linkRow =
      merge([
        pointsRow,
        style([
          marginBottom(`rem(4.75)),
          marginTop(`rem(1.3)),
          media(Theme.MediaQuery.notMobile, [marginTop(`rem(5.))]),
          media(Theme.MediaQuery.veryVeryLarge, [marginTop(`zero)]),
        ]),
      ]);
    let pointType =
      merge([
        Theme.H4.header,
        style([
          display(`block),
          position(`relative),
          top(`px(5)),
          textAlign(`center),
        ]),
      ]);
    let rank =
      merge([
        Theme.H6.extraSmall,
        style([
          textTransform(`uppercase),
          color(Theme.Colors.saville),
          fontSize(`rem(1.)),
          lineHeight(`rem(1.5)),
        ]),
      ]);
    let points = merge([flexColumn, style([marginLeft(`rem(2.))])]);
    let value =
      merge([
        Theme.H3.basic,
        style([
          fontSize(`rem(2.25)),
          fontWeight(`semiBold),
          color(Theme.Colors.saville),
          marginTop(`px(10)),
        ]),
      ]);
  };

  module PointsColumn = {
    [@react.component]
    let make = (~pointType, ~rank, ~points) => {
      <div className=Styles.pointsColumn>
        <span className=Styles.pointType> {React.string(pointType)} </span>
        <div className=Styles.rankAndPoints>
          <span className=Styles.pointsColumn>
            <span className=Styles.rank> {React.string("Rank")} </span>
            <span className=Styles.value> {React.string(rank)} </span>
          </span>
          <div className=Styles.points>
            <span className=Styles.rank> {React.string("Points *")} </span>
            <span className=Styles.value> {React.string(points)} </span>
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
    <div className=Styles.pointsRow>
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