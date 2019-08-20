let extraHeaders = () =>
  <>
    <script src="https://apis.google.com/js/api.js" />
    <script src={Links.Cdn.url("/static/js/leaderboard.js")} />
  </>;

module Styles = {
  open Css;

  let header =
    style([
      display(`flex),
      flexDirection(`column),
      width(`percent(100.)),
      color(Style.Colors.slate),
      textAlign(`center),
      margin2(~v=rem(3.5), ~h=`zero),
    ]);

  let content =
    style([
      display(`flex),
      flexDirection(`columnReverse),
      justifyContent(`center),
      media(Style.MediaQuery.somewhatLarge, [flexDirection(`row)]),
    ]);

  let leaderboard =
    style([
      background(Style.Colors.hyperlinkAlpha(0.15)),
      width(`percent(100.)),
      maxWidth(rem(41.)),
      borderRadius(px(3)),
      padding2(~v=`rem(1.), ~h=`zero),
      Style.Typeface.pragmataPro,
      lineHeight(rem(1.5)),
      color(Style.Colors.midnight),
      selector(
        ".leaderboard-row",
        [
          display(`grid),
          gridColumnGap(rem(1.)),
          gridTemplateColumns([rem(2.5), `auto, rem(6.)]),
        ],
      ),
      selector("div span:nth-child(odd)", [justifySelf(`flexEnd)]),
      selector(
        "hr",
        [
          height(px(4)),
          borderTop(px(1), `dashed, Style.Colors.marine),
          borderLeft(`zero, solid, transparent),
          borderBottom(px(1), `dashed, Style.Colors.marine),
        ],
      ),
      selector(
        "#leaderboard-loading",
        [
          textAlign(`center),
          marginTop(rem(2.)),
          color(Style.Colors.slateAlpha(0.7)),
        ],
      ),
      selector("div", [padding2(~v=`zero, ~h=`rem(1.))]),
      selector("div:nth-child(even)", [backgroundColor(`rgba(71, 130, 130, 0.1))]),
    ]);

  let headerRow =
    merge([
      Style.Body.basic_semibold,
      style([
        display(`grid),
        color(Style.Colors.midnight),
        gridColumnGap(rem(1.)),
        gridTemplateColumns([rem(2.5), `auto, rem(6.)]),
      ]),
    ]);

  let copy =
    style([
      width(rem(28.)),
      margin3(~top=`zero, ~h=`auto, ~bottom=rem(2.)),
      media(Style.MediaQuery.somewhatLarge, [marginLeft(rem(5.))]),
      ...Style.Body.basicStyles,
    ]);

  let leaderboardLink =
    merge([
      Style.Link.basic,
      Style.H3.basic,
      style([
        fontWeight(`semiBold),
        marginTop(rem(0.75)),
      ]),
    ]);
};

let component = ReasonReact.statelessComponent("Testnet");
let make = _children => {
  ...component,
  render: _self => {
    <div>
      <div className=Styles.header>
        <h1 className=Style.H1.hero>
          {ReasonReact.string("Testnet Leaderboard")}
        </h1>
        <a
          href="https://docs.google.com/spreadsheets/d/1CLX9DF7oFDWb1UiimQXgh_J6jO4fVLJEcEnPVAOfq24/edit#gid=0"
          target="_blank"
          className=Styles.leaderboardLink
        >
          {ReasonReact.string({j|View Full Leaderboard\u00A0→|j})}
        </a>
      </div>
      <div className=Styles.content>
        <div id="testnet-leaderboard" className=Styles.leaderboard>
          <div className=Styles.headerRow>
            <span> {ReasonReact.string("Rank")} </span>
            <span> {ReasonReact.string("Username")} </span>
            <span> {ReasonReact.string("Total")} </span>
          </div>
          <hr />
          <div id="leaderboard-loading">
            {ReasonReact.string("Loading...")}
          </div>
        </div>
        <div className=Styles.copy>
          <p>
            {ReasonReact.string(
               "The goal of Testnet Points* is to recognize Coda community members who are actively involved in the network. There will be regular challenges to make it fun, interesting, and foster some friendly competition! Points can be won in several ways like being first to complete a challenge, contributing code to Coda, or being an excellent community member and helping others out.",
             )}
          </p>
          <p> <h4> {ReasonReact.string("Challenge #1")} </h4> </p>
          <p>
            {ReasonReact.string(
               "Connect to Testnet - 1000 pts for anyone who sends a transaction to the echo service BONUS: An additional 2000 pts to the first person to complete the challenge, and an additional 1000 points to the second person to complete the challenge.",
             )}
          </p>
          <p> <strong> {ReasonReact.string("Challenge #2")} </strong> </p>
          <p>
            {ReasonReact.string(
               "Community Helper - 300 pts are awarded to anyone who helps another member of the community. This could include answering a question, helping them navigate the docs, and generally giving support and encouragement for those trying hard to get involved. We can only award points for what we see, so make sure you're doing it in one of the official testnet channels so everyone can learn!",
             )}
          </p>
          <p> <strong> {ReasonReact.string("Challenge #3")} </strong> </p>
          <p>
            {ReasonReact.string(
               "Join Discord - 100 pts awarded for introducing yourself in the #testnet-general channel. Name, location and what you're excited about are all good things to share in order to get the points!",
             )}
          </p>
          <p>
            <strong> {ReasonReact.string("Challenge #4 (on-going)")} </strong>
          </p>
          <p>
            {ReasonReact.string(
               "Community MVP - Each week, we will recognize the winners of the previous week based on the point values below. We may give out all the awards in a week, or none, or several at each level. The more active the community is, the more points* we can award in this category.",
             )}
          </p>
          <p>
            <strong> {ReasonReact.string("Gold - 1000 pts")} </strong>
            {ReasonReact.string(
               " - made a major, or on-going contribution to the community throughout the week. A major stand-out!",
             )}
          </p>
          <p>
            <strong> {ReasonReact.string("Silver - 500 pts")} </strong>
            {ReasonReact.string(
               " - always there, always helping, always positive!",
             )}
          </p>
          <p>
            <strong>
              {ReasonReact.string("Challenge #5 (on-going):")}
            </strong>
            {ReasonReact.string(" Major and Minor Bug Bounties")}
          </p>
          <p>
            <strong> {ReasonReact.string("Major - 2000 pts")} </strong>
            {ReasonReact.string(
               " - reported a new daemon crash that wasn't already on the known issues list.",
             )}
          </p>
          <p>
            <strong> {ReasonReact.string("Minor - 200 pts")} </strong>
            {ReasonReact.string(
               " - reported a new issue related to minor bugs in the daemon, documentation, or testnet.",
             )}
          </p>
          <p>
            <em>
              {ReasonReact.string(
                 "* Testnet Points are designed solely to track contributions to the Testnet and Testnet Points have no cash or other monetary value. Testnet Points and are not transferable and are not redeemable or exchangeable for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.",
               )}
            </em>
          </p>
        </div>
      </div>
    </div>;
  },
};
