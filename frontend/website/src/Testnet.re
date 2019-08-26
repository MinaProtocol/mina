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
      marginBottom(`rem(1.)),
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
      style([
        marginTop(rem(1.5)),
        marginBottom(rem(2.25)),
      ]),
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
        marginBottom(`rem(1.)),
        width(`rem(10.)),
        height(`rem(2.5)),
        display(`block),
        cursor(`pointer),
        borderRadius(`px(4)),
        padding2(~v=`rem(0.25), ~h=`rem(3.)),
        fontWeight(`semiBold),
        lineHeight(`rem(2.5)),
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
            [
              (0, Style.Colors.white),
              (100, Style.Colors.whiteAlpha(0.)),
            ],
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
      <div className=Styles.gradientSection>
        children
      </div>
      <label
        id=labelName
        className=Styles.expandButton
        htmlFor=checkboxName>
        {React.string("Expand " ++ name ++ {js| ↓|js})}
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
        <h1 className=Style.H1.hero> {React.string("Testnet Leaderboard")} </h1>
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
            <h2 className=Styles.weekHeader> {React.string("Week 5")} </h2>
          </p>
          <p>
            <h4 className=Styles.sidebarHeader>
              {React.string("Challenge #12: 'CLI FYI'")}
            </h4>
          </p>
          <p>
            {React.string(
              "Submit a product improvement or feature you'd like to see in the Coda command line interface (CLI). Post a new thread on the Discourse ",
            )}
            <a
              className=Style.Link.basic
              href="http://forums.codaprotocol.com"
              target="_blank">
              {React.string("forums")}
            </a>
            {React.string(
              " in the 'Product' category and add this to the title: '[CLI Feature]'. The community can vote on it by 'hearting' the post, and comment / discuss details in the thread. Add your Discord username to be counted for pts*.",
            )}
          </p>
          <p>
            {React.string(
              "Every feasible feature suggested will get 500 pts*. Top 5 features will win a bonus - and the community gets to vote for top 5. Bonus: 2500, 2000, 1500, 1000, 500 pts* respectively. Feasible feature means well scoped ideas that Coda could technically implement -- eg. The block producing CLI command should tell you % likelihood of winning a block and the time until the next slot you can produce blocks for. No guarantees that suggested features will be implemented. But if you submit a PR implementing one, you could win a massive bonus of 5000 pts*!",
            )}
          </p>
          <p>
            <h4 className=Styles.sidebarHeader>
              {React.string("Challenge #13: 'My two codas'")}
            </h4>
          </p>
          <p>
            {React.string(
              "Earn 400 pts* for giving your feedback by filling out this ",
            )}
            <a
              className=Style.Link.basic
              href="http://bit.ly/CommunityRetro"
              target="_blank">
              {React.string("survey")}
            </a>
            {React.string(".")}
          </p>
          <p>
            <h4 className=Styles.sidebarHeader>
              {React.string("Challenge #14: 'Leonardo da Coda'")}
            </h4>
          </p>
          <p>
            {React.string(
              "Bring out your most creative self to create Coda-related GIFs and emoji's! Post your GIF or emoji on the ",
            )}
            <a
              className=Style.Link.basic
              href="https://forums.codaprotocol.com/t/community-art-contest-gifs/109"
              target="_blank">
              {React.string("forums")}
            </a>
            {React.string(
              ". You can have unlimited number of entries so cut yourself loose! The community can vote on the best entries by 'hearting' your post, so do not forget to 'heart' your favorite entries! Top 3 entries will receive bonus points: 300 pts* for the best GIF and emoji, 200 pts* for the second place and 100 pts* for the third place.",
            )}
          </p>
        </div>
      </div>
    </Section>
    <hr/>
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
        src="https://o1testnet.grafana.net/d-solo/mO5fAWHWk/testnet-stats?orgId=1&from=1566752668214&to=1566839068215&panelId=4"
        className=Styles.dashboard>
      </iframe>
    </div>
  </div>;
};
