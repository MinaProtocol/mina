module Styles = {
  open Css;
  let linkRow =
    style([
      media(
        Theme.MediaQuery.desktop,
        [marginTop(`rem(4.8)), paddingTop(`rem(5.))],
      ),
    ]);
  let cookieRow =
    style([
      media(
        Theme.MediaQuery.desktop,
        [
          width(`rem(30.)),
          display(`flex),
          justifyContent(`spaceBetween),
          alignItems(`baseline),
        ],
      ),
    ]);
  let header =
    merge([
      Theme.Type.h1,
      style([
        fontSize(`rem(1.5)),
        lineHeight(`rem(2.)),
        marginBottom(`rem(0.)),
        media(
          Theme.MediaQuery.notMobile,
          [fontSize(`rem(3.)), lineHeight(`rem(3.))],
        ),
      ]),
    ]);
  let links =
    merge([
      Theme.Type.link,
      style([fontSize(`rem(1.5)), color(Theme.Colors.orange)]),
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
  let link = merge([Theme.Type.link, style([lineHeight(`px(28))])]);
  let participantDetails =
    merge([
      Theme.Type.paragraphMono,
      style([
        display(`none),
        media(
          Theme.MediaQuery.notMobile,
          [
            display(`inlineBlock),
            color(Theme.Colors.black),
            textTransform(`uppercase),
          ],
        ),
      ]),
    ]);
  let cookieCrumb =
    merge([
      Theme.Type.paragraphMono,
      style([
        display(`none),
        media(
          Theme.MediaQuery.notMobile,
          [
            display(`inlineBlock),
            color(Theme.Colors.orange),
            textTransform(`uppercase),
            textDecoration(`none),
          ],
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
        Theme.MediaQuery.desktop,
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
          Theme.MediaQuery.desktop,
          [
            flexDirection(`column),
            marginTop(`zero),
            marginRight(`zero),
            width(`rem(18.75)),
          ],
        ),
      ]),
    ]);
  let linksColumn =
    merge([
      flexColumn,
      style([
        position(`relative),
        marginTop(`rem(2.)),
        media(Theme.MediaQuery.notMobile, [marginTop(`zero)]),
        media(
          Theme.MediaQuery.desktop,
          [position(`unset), marginTop(`rem(2.))],
        ),
      ]),
    ]);

  let nameContainer =
    style([
      display(`flex),
      flexDirection(`column),
      alignItems(`flexStart),
      media(
        Theme.MediaQuery.notMobile,
        [flexDirection(`row), alignItems(`center)],
      ),
    ]);

  let username = merge([header, style([marginRight(`rem(1.5))])]);
};

module Links = {
  [@react.component]
  let make = () => {
    <div className=Styles.buttonAndLinks>
      <Button
        href=`External("https://forums.minaprotocol.com/t/testnet-beta-release-3-2b-challenges/435")
        bgColor=Theme.Colors.black>
        {React.string("Current Challenges")}
      </Button>
      <div className=Styles.linksColumn>
          <a href="https://bit.ly/leaderboardFAQ" className=Styles.link> {React.string("Leaderboard FAQ")} </a>
          <a href="https://bit.ly/MinaDiscord" className=Styles.link>
            {React.string("Discord #leaderboard-qa Channel")}
          </a>
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
        media(Theme.MediaQuery.notMobile, [marginTop(`rem(6.))]),
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
          [
            width(`rem(51.)),
            justifyContent(`spaceBetween),
            marginTop(`zero),
          ],
        ),
        media(
          Theme.MediaQuery.desktop,
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
          media(
            Theme.MediaQuery.desktop,
            [marginTop(`zero), paddingTop(`rem(5.))],
          ),
        ]),
      ]);

    let pointType =
      merge([
        Theme.Type.h4,
        style([
          display(`block),
          position(`relative),
          top(`px(5)),
          textAlign(`center),
        ]),
      ]);
    let rank =
      merge([
        Theme.Type.h6,
        style([
          textTransform(`uppercase),
          color(Theme.Colors.black),
          fontSize(`rem(1.)),
          lineHeight(`rem(1.5)),
          alignSelf(`center),
        ]),
      ]);
    let points = merge([flexColumn, style([marginLeft(`rem(1.))])]);
    let value =
      merge([
        Theme.Type.h3,
        style([
          fontSize(`rem(2.25)),
          fontWeight(`semiBold),
          color(Theme.Colors.black),
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

  let parsePointOrRank = n => {
    n == 0 ? "N/A" : string_of_int(n);
  };

  [@react.component]
  let make = (~member: Leaderboard.member) => {
    <div className=Styles.pointsRow>
      <PointsColumn
        pointType="This Release"
        rank={parsePointOrRank(member.releaseRank)}
        points={parsePointOrRank(member.releasePoints)}
      />
      <PointsColumn
        pointType="This Phase"
        rank={parsePointOrRank(member.phaseRank)}
        points={parsePointOrRank(member.phasePoints)}
      />
      <PointsColumn
        pointType="All Time"
        rank={parsePointOrRank(member.allTimeRank)}
        points={parsePointOrRank(member.allTimePoints)}
      />
    </div>;
  };
};

[@react.component]
let make = (~member: Leaderboard.member) => {
  <div className=Styles.linkRow>
    <div className=Styles.cookieRow>
      <Next.Link href="/testnet">
        <a className=Styles.cookieCrumb> {React.string("Testnet")} </a>
      </Next.Link>
      <svg
        height="11"
        width="10"
        fill="none"
        viewBox="0 0 10 15"
        xmlns="http://www.w3.org/2000/svg">
        <path
          d="M0 11.208L6.48 7.248V7.08L0 3.12V0L9.648 6.144V8.16L0 14.352V11.208Z"
          fill="#3D5878"
        />
      </svg>
      <Next.Link href="/leaderboard">
        <a className=Styles.cookieCrumb> {React.string("Leaderboard")} </a>
      </Next.Link>
      <svg
        height="11"
        width="10"
        fill="none"
        viewBox="0 0 10 15"
        xmlns="http://www.w3.org/2000/svg">
        <path
          d="M0 11.208L6.48 7.248V7.08L0 3.12V0L9.648 6.144V8.16L0 14.352V11.208Z"
          fill="#3D5878"
        />
      </svg>
      <span className=Styles.participantDetails>
        {React.string("Participant Details")}
      </span>
    </div>
    <div className=Styles.nameContainer>
      <p className=Styles.username> {React.string(member.name)} </p>
      <span className=Css.(style([display(`flex), paddingTop(`rem(0.5))]))>
        {Leaderboard.LeaderboardRow.renderBadges(
           ~marginLeft=0.5,
           ~marginRight=0.5,
           ~mobileMarginLeft=0.,
           ~mobileMarginRight=1.,
           ~height=2.,
           ~width=2.,
           member,
         )}
      </span>
    </div>
    <div className=Styles.middleRow> <Points member /> <Links /> </div>
  </div>;
};
