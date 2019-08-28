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
      marginTop(rem(1.)),
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
          gridColumnGap(rem(1.5)),
          gridTemplateColumns([rem(2.5), `auto, rem(6.), rem(2.5)]),
        ],
      ),
      selector("div span:last-child", [opacity(0.5)]),
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
      selector(
        "div:nth-child(even)",
        [backgroundColor(`rgba((71, 130, 130, 0.1)))],
      ),
    ]);

  let headerRow =
    merge([
      Style.Body.basic_semibold,
      style([
        display(`grid),
        color(Style.Colors.midnight),
        gridColumnGap(rem(1.5)),
        gridTemplateColumns([rem(2.5), `auto, rem(6.), rem(2.5)]),
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
        marginLeft(rem(1.75)),
      ]),
    ]);

  let sidebarHeader =
    merge([
      Style.H4.wide,
      style([textAlign(`left), fontSize(`rem(1.)), fontWeight(`light)]),
    ]);

  let weekHeader =
    merge([Style.H2.basic, style([padding2(~v=`rem(1.), ~h=`zero)])]);
};

[@react.component]
let make = () => {
  <div>
    <div className=Styles.header>
      <h1 className=Style.H1.hero> {React.string("Testnet Leaderboard")} </h1>
      <a
        href="https://docs.google.com/spreadsheets/d/1CLX9DF7oFDWb1UiimQXgh_J6jO4fVLJEcEnPVAOfq24/edit#gid=0"
        target="_blank"
        className=Styles.leaderboardLink>
        {React.string({j|View Full Leaderboard\u00A0→|j})}
      </a>
    </div>
    <div className=Styles.content>
      <div id="testnet-leaderboard" className=Styles.leaderboard>
        <div className=Styles.headerRow>
          <span> {React.string("Rank")} </span>
          <span> {React.string("Username")} </span>
          <span id="leaderboard-current-week" />
          <span> {React.string("Total")} </span>
        </div>
        <hr />
        <div id="leaderboard-loading"> {React.string("Loading...")} </div>
      </div>
      <div className=Styles.copy>
        <p>
          <h4 className=Styles.sidebarHeader>
            {React.string("Testnet Points")}
          </h4>
        </p>
        <p>
          {React.string(
             "The goal of Testnet Points* is to recognize Coda community members who are actively involved in the network. There will be regular challenges to make it fun, interesting, and foster some friendly competition! Points can be won in several ways like being first to complete a challenge, contributing code to Coda, or being an excellent community member and helping others out.",
           )}
        </p>
        <p>
          <h4 className=Styles.sidebarHeader>
            {React.string("Community")}
          </h4>
        </p>
        <p>
          <a className=Style.Link.basic href="/docs">
            {React.string("Testnet Docs")}
          </a>
          <br />
          <a
            className=Style.Link.basic
            href="https://bit.ly/CodaDiscord"
            target="_blank">
            {React.string("Discord")}
          </a>
          <br />
          <a
            className=Style.Link.basic
            href="https://forums.codaprotocol.com"
            target="_blank">
            {React.string("Coda Forums")}
          </a>
        </p>
        <p>
          <h2 className=Styles.weekHeader> {React.string("Week 6")} </h2>
        </p>
        <p>
          <h4 className=Styles.sidebarHeader>
            {React.string("Challenge #15: 'Something Snarky'")}
          </h4>
        </p>
        <p>
          {React.string(
             "This week's challenge makes snark work the primary objective. Node operators that produce at least one SNARK will get 1000 pts*.",
           )}
        </p>
        <p>
          {React.string(
             "BONUS: Top 3 node operators who are able to sell the most SNARKs on the snarketplace (meaning your SNARK was not just produced, but also selected by a block producer) will win 3000, 2000, and 1000 pts* respectively. Hint: your SNARKs are more likely to be bought if the fees are lower ;)",
           )}
        </p>
        <p className=Css.(style([fontStyle(`italic)]))>
          {React.string(
             "* Testnet Points are designed solely to track contributions to the Testnet and Testnet Points have no cash or other monetary value. Testnet Points and are not transferable and are not redeemable or exchangeable for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.",
           )}
        </p>
      </div>
    </div>
  </div>;
};
