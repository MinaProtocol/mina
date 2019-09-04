let extraHeaders = () =>
  <>
    <script src="https://apis.google.com/js/api.js" />
    <script src={Links.Cdn.url("/static/js/leaderboard.js")} />
  </>;

module Styles = {
  open Css;

  let page =
    style([
      selector(
        "hr",
        [
          height(px(4)),
          borderTop(px(1), `dashed, Style.Colors.marine),
          borderLeft(`zero, solid, transparent),
          borderBottom(px(1), `dashed, Style.Colors.marine),
        ],
      ),
    ]);

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
      width(`percent(100.)),
      marginBottom(`rem(1.5)),
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

  let headerLink =
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

  let dashboardHeader =
    merge([
      header,
      style([marginTop(rem(1.5)), marginBottom(rem(2.25))]),
    ]);

  let dashboard =
    style([
      width(`percent(100.)),
      height(`rem(30.)),
      border(`px(0), `solid, white),
      borderRadius(px(3)),
    ]);

  let expandButton =
    merge([
      Style.Link.basic,
      style([
        backgroundColor(Style.Colors.hyperlink),
        color(white),
        marginLeft(`auto),
        marginRight(`auto),
        marginBottom(`rem(1.5)),
        width(`rem(10.)),
        height(`rem(2.5)),
        display(`block),
        cursor(`pointer),
        borderRadius(`px(4)),
        padding2(~v=`rem(0.25), ~h=`rem(3.)),
        fontWeight(`semiBold),
        lineHeight(`rem(2.5)),
        hover([backgroundColor(Style.Colors.hyperlinkHover), color(white)]),
      ]),
    ]);

  let gradientSection =
    style([
      position(`relative),
      height(`rem(45.)),
      overflow(`hidden),
      display(`flex),
      flexWrap(`wrap),
      marginLeft(`auto),
      marginRight(`auto),
      justifyContent(`center),
      after([
        contentRule(""),
        position(`absolute),
        bottom(`px(-1)),
        left(`zero),
        height(`rem(8.)),
        width(`percent(100.)),
        pointerEvents(`none),
        backgroundImage(
          `linearGradient((
            `deg(0),
            [(0, Style.Colors.white), (100, Style.Colors.whiteAlpha(0.))],
          )),
        ),
      ]),
    ]);
};

module Section = {
  [@react.component]
  let make = (~name, ~children) => {
    let checkboxName = name ++ "-checkbox";
    let labelName = name ++ "-label";
    <div className=Css.(style([display(`flex), flexDirection(`column)]))>
      <input
        type_="checkbox"
        id=checkboxName
        className=Css.(
          style([
            display(`none),
            selector(
              ":checked + div",
              [height(`auto), after([display(`none)])],
            ),
            selector(":checked ~ #" ++ labelName, [display(`none)]),
          ])
        )
      />
      <div className=Styles.gradientSection> children </div>
      <label id=labelName className=Styles.expandButton htmlFor=checkboxName>
        {React.string("Expand " ++ name)}
        <div
          className=Css.(
            style([
              position(`relative),
              bottom(`rem(2.6)),
              left(`rem(9.6)),
            ])
          )>
          {React.string({js| ↓|js})}
        </div>
      </label>
      <RunScript>
        {Printf.sprintf(
           {|document.getElementById("%s").checked = false;|},
           checkboxName,
         )}
      </RunScript>
    </div>;
  };
};

[@react.component]
let make = () => {
  <div className=Styles.page>
    <Section name="Leaderboard">
      <div className=Styles.header>
        <h1 className=Style.H1.hero>
          {React.string("Testnet Leaderboard")}
        </h1>
        <a
          href="https://docs.google.com/spreadsheets/d/1CLX9DF7oFDWb1UiimQXgh_J6jO4fVLJEcEnPVAOfq24/edit#gid=0"
          target="_blank"
          className=Styles.headerLink>
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
            <h2 className=Styles.weekHeader> {React.string("Week 7")} </h2>
          </p>
          <p>
            <h4 className=Styles.sidebarHeader>
              {React.string("Challenge #16: 'New Member Welcome Bonus'")}
            </h4>
          </p>
          <p>
          <span>
            {React.string("This week, we have a package deal with a big bonus for new members. This would be a great chance to invite your friends to join! New members who complete all of the following three challenges this week will receive two times the total points* value as a bonus: #1 'Connect to Testnet', #3 'Join Discord', and #6 'Nice to Meet You' (check out all challenge descriptions ")}
          </span>
            <a className=Style.Link.basic href="/docs/coda-testnet">
              {React.string("here")}
            </a>
          <span>
            {React.string("). So instead of 700 pts* (respectively 500 + 100 + 100), new users will receive 1400 pts* ! - ")}
          </span>
            <a className=Style.Link.basic href="/docs/getting-started">
              {React.string("Get started!")}
            </a>
          </p>
          <p>
            <h4 className=Styles.sidebarHeader>
              {React.string("Challenge #17: 'Hello Memo'")}
            </h4>
          </p>
          <p>
            {React.string(
               "Did you know that Coda supports 32bytes of memos in its transactions? You can fit a SHA256 hash. Think of the possibilities! For this challenge, we'd like you to send a single transaction with a memo inside of it. coda client send-payment now supports a -memo flag. In that memo please stick the string \"Hello Memo\". You can send this transaction to anyone, for example a friend. You'll earn 500 pts* for doing so. As always, please hit the faucet with your discord account so that we can associate a public key with your discord username in order to add your score to the leaderboard.",
             )}
          </p>
          <p>
            <h4 className=Styles.sidebarHeader>
              {React.string("Challenge #18: 'Oops'")}
            </h4>
          </p>
          <p>
            {React.string(
               "Coda also supports cancelling transactions -- you just need to make sure to cancel it before it gets included inside a block! For this challenge, we'd like you to cancel a transaction. This means, (a) you must send a transaction and (b) take the transaction-id that comes out and then cancel it again with coda client cancel-transaction . You'll earn 500 pts* for doing so.  In order to incentivize nodes to accept your cancellations, a fee is debited from your account greater than the fee that's present in the transaction pool. You'll know if the cancellation when through if after a while you notice your balance is lowered (by the fees from the cancellation). As always, please hit the faucet with your discord account so that we can associate a public key with your discord username in order to add your score to the leaderboard.",
             )}
          </p>
          <p>
            <h4 className=Styles.sidebarHeader>
              {React.string("Challenge #19: 'GraphCoolL'")}
            </h4>
          </p>
          <p>
            {React.string(
               "Coda has a GraphQL API! It's super experimental, and we are already in the process of changing several parts of it, but we've noticed that some in the community have already successfully built interesting tools on top of our API. We're interested in getting your feedback! We want you to build something cool on GraphQL and tell us how we can make it better. You'll earn 500 pts* for building something and including some sort of constructive feedback (note anything you have issues with, you wish were different, things that were easy, etc). Please share it as a post on discourse with a [GraphQL] tag. [GraphQL] Your title here . In order to receive points, you must (a) include your source code (via a link to a public repo on github or embedded on the forums) and license it under the Apache2 license and (b) include some sort of constructive feedback (note anything you have issues with, you wish were different, things that were easy, etc).",
             )}
          </p>
          <p>
            {React.string(
               "You'll earn 500 pts* for sending us anything that we feel has achieved (a) and (b), as described above, and we'll award a BONUS of an additional 2000 pts* for the coolest use and 1000 pts* for second place! Good luck.",
             )}
          </p>
          <p className=Css.(style([fontStyle(`italic)]))>
            {React.string(
               "* Testnet Points are designed solely to track contributions to the Testnet and Testnet Points have no cash or other monetary value. Testnet Points and are not transferable and are not redeemable or exchangeable for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.",
             )}
          </p>
        </div>
      </div>
    </Section>
    <hr />
    <div>
      <div className=Styles.dashboardHeader>
        <h1 className=Style.H1.hero> {React.string("Network Dashboard")} </h1>
        <a
          href="https://o1testnet.grafana.net/d/mO5fAWHWk/testnet-stats?orgId=1"
          target="_blank"
          className=Styles.headerLink>
          {React.string({j|View Full Dashboard\u00A0→|j})}
        </a>
      </div>
      <iframe
        src="https://o1testnet.grafana.net/d-solo/PeI0mtKWk/live-dashboard-for-website?orgId=1&panelId=2"
        className=Styles.dashboard
      />
    </div>
  </div>;
};
