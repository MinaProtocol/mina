let extraHeaders = () =>
  <>
    <script src="https://apis.google.com/js/api.js" />
    <script src={Links.Cdn.url("/static/js/leaderboard.js")} />
    <script
      src="https://cdnjs.cloudflare.com/ajax/libs/marked/0.7.0/marked.min.js"
      integrity="sha256-0Ed5s/n37LIeAWApZmZUhY9icm932KvYkTVdJzUBiI4="
      crossOrigin="anonymous"
    />
  </>;

module Styles = {
  open Css;

  let markdownStyles =
    style([
      selector(
        "a",
        [
          hover([color(Style.Colors.hyperlinkHover)]),
          cursor(`pointer),
          ...Style.Link.basicStyles,
        ],
      ),
      selector(
        "h4",
        Style.H4.wideStyles
        @ [textAlign(`left), fontSize(`rem(1.)), fontWeight(`light)],
      ),
      selector(
        "code",
        [Style.Typeface.pragmataPro, color(Style.Colors.midnight)],
      ),
      selector(
        "p > code, li > code",
        [
          boxSizing(`borderBox),
          padding2(~v=`px(2), ~h=`px(6)),
          backgroundColor(Style.Colors.slateAlpha(0.05)),
          borderRadius(`px(4)),
        ],
      ),
    ]);

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
      //textAlign(`center),
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
      overflow(`scroll),
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
          gridTemplateColumns([rem(1.), rem(5.5), rem(5.5), rem(2.5)]),
          width(`rem(25.)),
          media(Style.MediaQuery.notMobile, 
            [
              gridTemplateColumns([rem(2.5), `auto, rem(6.), rem(2.5)]),
              width(`percent(100.))
            ]),
        ],
      ),
      selector(
        ".leaderboard-row > span", 
        [
          textOverflow(`ellipsis),
          whiteSpace(`nowrap),
          overflow(`hidden),
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
        gridTemplateColumns([rem(1.), rem(5.5), rem(5.5), rem(2.5)]),
        media(Style.MediaQuery.notMobile, 
        [
          width(`percent(100.)),
          gridTemplateColumns([rem(1.), `auto, rem(6.), rem(2.5)]),
        ]),
      ]),
    ]);

  let copy =
    style([
      maxWidth(rem(28.)),
      margin3(~top=`zero, ~h=`auto, ~bottom=rem(2.)),
      media(Style.MediaQuery.somewhatLarge, [marginLeft(rem(5.))]),
      media(Style.MediaQuery.notMobile, [width(rem(28.))]),
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
      width(`percent(100.)),
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
  
  let buttonRow = 
    style([
      display(`flex),
      flexWrap(`wrap),
      marginLeft(`auto),
      marginRight(`auto),
      marginTop(rem(3.)),
      marginBottom(rem(3.)),
      justifyContent(`spaceBetween),
      alignItems(`center),
      flexDirection(`column),
      media(Style.MediaQuery.notMobile, [flexDirection(`row)]),
    ]);
  let ctaButton = 
  style([
    padding(`px(30)),        
    background(`rgba(71, 137, 196, 0.1)),
    border(`px(1), `solid, `hex("2D9EDB")),
    borderRadius(`rem(0.25)),
    maxWidth(`px(300)),
    marginTop(`px(10)),
  ]);
  let ctaContent = 
  style([
    display(`flex),
    flexDirection(`column),
  ])
  let ctaText = 
  style([
    Style.Typeface.ibmplexsans,
    fontWeight(`num(600)),
    fontSize(`px(30)),
    lineHeight(`px(48)),
    color(`hex("4782A0"))
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
    <div className=Styles.header>
      <h1 className=Style.H1.hero>
            {React.string("Coda Public Testnet")}
      </h1> 
      <p className=Style.Body.basic> 
        {React.string("Coda's public testnet is live! There are weekly challenges for the community to interact with the testnet and contribute to Coda's development. Each week features a new competition to recognize and reward top contributors with testnet points.")}
      </p> 
      <br />
      <p className=Style.Body.basic> 
        {React.string("By participating in the testnet, you'll be helping advance the first cryptocurrency that utilizes recursive zk-SNARKs and production-scale Ouroboros proof of stake consensus.")}
      </p> 
    </div>
    <hr /> 
    <div>
      <div className=Styles.buttonRow>
      <a href="/docs/getting-started/">
       <button className=Styles.ctaButton> 
       <div className=Styles.ctaContent> 
        <h2 className=Styles.ctaText>
          {React.string({js| 📋 Get Started |js})} 
        </h2> 
        <h4 className=Style.Body.small> 
          {React.string("Get started by installing Coda and running a node")}
          </h4> 
          </div>
        </button> 
      </a>
      <a href="https://bit.ly/CodaDiscord">
       <button className=Styles.ctaButton> 
       <div>
        <h2 className=Styles.ctaText>
          {React.string({js|🔥 Discord |js})} 
          </h2> 
          <h4 className=Style.Body.small> 
          {React.string("Connect with the community and participate in weekly challenges")}
          </h4> 
        </div>
        </button> 
      </a>
      <a href="https://forums.codaprotocol.com/">
       <button className=Styles.ctaButton> 
        <h2 className=Styles.ctaText>
          {React.string({js|💬 Forum |js})} 
          </h2> 
          <h4 className=Style.Body.small> 
          {React.string("Find longer discussions and in-depth content")}
          </h4> 
       </button>
       </a>
       <button className=Styles.ctaButton> 
        <h2 className=Styles.ctaText>
            {React.string({js|📬 Newsletter |js})} 
            </h2> 
            <h4 className=Style.Body.small> 
            {React.string("Sign up for the newsletter to get weekly updates")}
            </h4> 
          </button>
      </div> 
    </div> 
    <hr />
    <Section name="Leaderboard">
      <div className=Styles.header>
        <h1 className=Style.H1.hero>
          {React.string("Testnet Leaderboard")}
        </h1>
        // <a
        //   href="https://docs.google.com/spreadsheets/d/1CLX9DF7oFDWb1UiimQXgh_J6jO4fVLJEcEnPVAOfq24/edit#gid=0"
        //   target="_blank"
        //   className=Styles.headerLink>
        //   {React.string({j|View Full Leaderboard\u00A0→|j})}
        // </a>
      </div>
      <div className=Styles.content>
        <div id="testnet-leaderboard" className=Styles.leaderboard>
          <div className=Styles.headerRow>
            <span> {React.string("#")} </span>
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
            <h2 id="challenges-current-week" className=Styles.weekHeader />
          </p>
          <p> <div id="challenges-list" className=Styles.markdownStyles /> </p>
          <p id="disclaimer" className=Css.(style([fontStyle(`italic)]))>
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
  </div>
};
