let extraHeaders = () =>
  <>
    <script src="https://apis.google.com/js/api.js" />
    <script src={Links.Cdn.url("/static/js/leaderboard.js")} />
    <script
      src="https://cdnjs.cloudflare.com/ajax/libs/marked/0.7.0/marked.min.js"
      integrity="sha256-0Ed5s/n37LIeAWApZmZUhY9icm932KvYkTVdJzUBiI4="
      crossOrigin="anonymous"
    />
    <script src={Links.Cdn.url("/static/js/termynal.js")} />
    <link rel="stylesheet" href={Links.Cdn.url("/static/css/termynal.css")} />
  </>;

// TODO: Extract this icon
module Icon = {
  let fillStyle = colorVar =>
    ReactDOMRe.Style.unsafeAddProp(
      ReactDOMRe.Style.make(),
      "fill",
      "var(" ++ colorVar ++ ")",
    );
  module Svg = {
    let discord =
      <svg
        height="39px"
        viewBox="0 0 38 55"
        version="1.1"
        xmlns="http://www.w3.org/2000/svg"
        xmlnsXlink="http://www.w3.org/1999/xlink">
        <defs>
          <polygon
            id="path-1"
            points="7.77142857e-05 0 34 0 34 37.999924 7.77142857e-05 37.999924"
          />
        </defs>
        <g
          id="coda_website"
          stroke="none"
          strokeWidth="1"
          fill="none"
          fillRule="evenodd">
          <g
            id="coda_homepage"
            transform="translate(-763.000000, -3290.000000)">
            <g id="Community" transform="translate(418.000000, 3032.000000)">
              <g id="Discord" transform="translate(345.000000, 258.000000)">
                <g id="IconDiscord">
                  <path
                    d="M19.944064,16.423984 C19.032064,16.423984 18.312064,17.223984 18.312064,18.199984 C18.312064,19.175984 19.047904,19.975984 19.944064,19.975984 C20.855904,19.975984 21.575904,19.175984 21.575904,18.199984 C21.575904,17.223984 20.855904,16.423984 19.944064,16.423984 M14.104064,16.423984 C13.192064,16.423984 12.472064,17.223984 12.472064,18.199984 C12.472064,19.175984 13.207904,19.975984 14.104064,19.975984 C15.016064,19.975984 15.736064,19.175984 15.736064,18.199984 C15.752064,17.223984 15.016064,16.423984 14.104064,16.423984"
                    id="Eyes"
                    fill=Style.Colors.(string(greyBlue))
                  />
                  <g id="Bubble">
                    <mask id="mask-2" fill="white">
                      <use xlinkHref="#path-1" />
                    </mask>
                    <g id="Clip-4" />
                    <path
                      d="M22.517792,24.813924 C22.517792,24.813924 21.8181691,23.996924 21.235312,23.274924 C23.7806491,22.571924 24.7520777,21.013924 24.7520777,21.013924 C23.955312,21.526924 23.197792,21.888114 22.517792,22.134924 C21.5463634,22.533924 20.6135977,22.799924 19.7006491,22.951924 C17.835312,23.293924 16.125792,23.198924 14.6686491,22.933114 C13.5610263,22.723924 12.6092206,22.419924 11.8124549,22.116114 C11.365792,21.944924 10.8800777,21.736114 10.3943634,21.469924 C10.3360777,21.431924 10.277792,21.413114 10.2195063,21.374924 C10.1806491,21.356114 10.1610263,21.336924 10.141792,21.318114 C9.79207771,21.128114 9.597792,20.994924 9.597792,20.994924 C9.597792,20.994924 10.5303634,22.514924 12.997792,23.236924 C12.4149349,23.958924 11.6960777,24.813924 11.6960777,24.813924 C7.40236343,24.681114 5.77036343,21.926114 5.77036343,21.926114 C5.77036343,15.808114 8.56807771,10.848924 8.56807771,10.848924 C11.365792,8.796924 14.0275063,8.853924 14.0275063,8.853924 L14.221792,9.081924 C10.7246491,10.069924 9.11207771,11.570924 9.11207771,11.570924 C9.11207771,11.570924 9.53950629,11.343114 10.2581691,11.019924 C12.3372206,10.126924 13.9886491,9.879924 14.6686491,9.823114 C14.7852206,9.803924 14.8823634,9.784924 14.9989349,9.784924 C16.1838834,9.633114 17.5246491,9.594924 18.9235063,9.746924 C20.7692206,9.955924 22.7507406,10.488114 24.7715063,11.570924 C24.7715063,11.570924 23.2364549,10.145924 19.9335977,9.158114 L20.205792,8.853924 C20.205792,8.853924 22.8675063,8.796924 25.6650263,10.848924 C25.6650263,10.848924 28.4629349,15.808114 28.4629349,21.926114 C28.4629349,21.926114 26.8115063,24.681114 22.517792,24.813924 M30.0172206,-7.6e-05 L3.98293486,-7.6e-05 C1.78750629,-7.6e-05 7.77142857e-05,1.748114 7.77142857e-05,3.913924 L7.77142857e-05,29.601924 C7.77142857e-05,31.768114 1.78750629,33.516114 3.98293486,33.516114 L26.0149349,33.516114 L24.9850263,30.001114 L27.4720777,32.261924 L29.8229349,34.389924 L34.0000777,37.999924 L34.0000777,3.913924 C34.0000777,1.748114 32.2124549,-7.6e-05 30.0172206,-7.6e-05"
                      id="Fill-3"
                      fill=Style.Colors.(string(greyBlue))
                      mask="url(#mask-2)"
                    />
                  </g>
                </g>
              </g>
            </g>
          </g>
        </g>
      </svg>;
  };
};

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
      textAlign(`center),
      margin2(~v=rem(3.5), ~h=`zero),
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

  let rowStyles = [
    display(`grid),
    gridColumnGap(rem(1.5)),
    gridTemplateColumns([rem(1.), rem(5.5), rem(5.5), rem(2.5)]),
    media(
      Style.MediaQuery.notMobile,
      [
        width(`percent(100.)),
        gridTemplateColumns([rem(2.5), `auto, rem(6.), rem(2.5)]),
      ],
    ),
  ];

  let row = style(rowStyles);

  let leaderboard =
    style([
      background(Style.Colors.hyperlinkAlpha(0.15)),
      width(`percent(100.)),
      height(`rem(60.)),
      maxWidth(rem(41.)),
      borderRadius(px(3)),
      padding2(~v=`rem(1.), ~h=`zero),
      Style.Typeface.pragmataPro,
      lineHeight(rem(1.5)),
      color(Style.Colors.midnight),
      selector(".leaderboard-row", rowStyles),
      selector(
        ".leaderboard-row > span",
        [textOverflow(`ellipsis), whiteSpace(`nowrap), overflow(`hidden)],
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
      row,
      Style.Body.basic_semibold,
      style([color(Style.Colors.midnight)]),
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
      justifyContent(`spaceAround),
      alignItems(`center),
      flexDirection(`column),
      maxWidth(`rem(44.)),
      media("(min-width: 70rem)", [maxWidth(`percent(100.))]),
      media(Style.MediaQuery.notMobile, [flexDirection(`row)]),
    ]);

  let heroRow =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      alignItems(`center),
      media("(min-width: 70rem)", [flexDirection(`row)]),
    ]);

  let heroText =
    merge([header, style([maxWidth(`px(500)), textAlign(`left)])]);

  let termynal =
    style([
      height(`rem(16.875)),
      marginLeft(`rem(1.875)),
      fontSize(`rem(0.625)),
      media(
        Style.MediaQuery.notMobile,
        [
          padding2(~v=`rem(4.6875), ~h=`rem(2.1875)),
          height(`rem(25.)),
          fontSize(`rem(1.)),
        ],
      ),
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
let f = Links.Cdn.url;

[@react.component]
let make = () => {
  <div className=Styles.page>
    <div className=Styles.heroRow>
      <div className=Styles.heroText>
        <h1 className=Style.H1.hero>
          {React.string("Coda Public Testnet")}
        </h1>
        <p className=Style.Body.basic>
          {React.string(
             "Coda's public testnet is live! There are weekly challenges for the community \
                  to interact with the testnet and contribute to Coda's development. Each week \
                  features a new competition to recognize and reward top contributors with testnet \
                  points.",
           )}
        </p>
        <br />
        <p className=Style.Body.basic>
          {React.string(
             "By participating in the testnet, you'll be helping advance the first cryptocurrency that utilizes recursive zk-SNARKs and production-scale Ouroboros proof of stake consensus.",
           )}
        </p>
      </div>
      <div id="termynal" className=Styles.termynal>
        <RunScript>
          {|var termynal = new Termynal('#termynal', {
            typeDelay: 40,
            lineDelay: 700,
            lineData: [
              { type: 'input', prompt: '>', value: 'coda daemon -peer ...' },
              { type: 'progress' },
              { value:  'Daemon ready. Clients can now connect!'},
              { type: 'input', prompt: '>', value: 'coda client status' },
              { delay: '0', value:  'Max observed block length: 120'},
              { delay: '0', value:  'Peers: 23'},
              { delay: '0', value:  'Consensus time now: epoch=1, slot=13'},
              { delay: '0', value:  'Sync status: Synced'},
            ]
          });|}
        </RunScript>
      </div>
    </div>
    <div>
      <div className=Styles.buttonRow>
        <ActionButton
          icon={React.string({js| 📋 |js})}
          heading={React.string({js| Get Started |js})}
          text={React.string(
            "Get started by installing Coda and running a node",
          )}
          href="/docs/getting-started/"
        />
        <ActionButton
          icon=Icon.Svg.discord
          heading={React.string({js| Discord |js})}
          text={React.string(
            "Connect with the community and participate in weekly challenges",
          )}
          href="https://bit.ly/CodaDiscord"
        />
        <ActionButton
          icon={React.string({js|💬|js})}
          heading={React.string({js| Forum |js})}
          text={React.string("Find longer discussions and in-depth content")}
          href="https://forums.codaprotocol.com/"
        />
        <ActionButton
          icon={React.string({js| 📬 |js})}
          heading={React.string({js| Testnet Newsletter |js})}
          text={React.string(
            "Sign up for the newsletter to get weekly updates",
          )}
          href="https://docs.google.com/forms/d/e/1FAIpQLScQRGW0-xGattPmr5oT-yRb9aCkPE6yIKXSfw1LRmNx1oh6AA/viewform"
        />
      </div>
    </div>
    <hr />
    <Section name="Leaderboard">
      <div className=Styles.dashboardHeader>
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
          <p className=Styles.markdownStyles>
            {React.string("The goal of Testnet Points")}
            <a href="#disclaimer"> {React.string("*")} </a>
            {React.string(
               " is to recognize Coda community members who are actively involved in the network. There will be regular challenges to make it fun, interesting, and foster some friendly competition! Points can be won in several ways like being first to complete a challenge, contributing code to Coda, or being an excellent community member and helping others out.",
             )}
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
  </div>;
};
