module Styles = {
  open Css;
  let page =
    style([display(`block), justifyContent(`center), overflowX(`hidden)]);

  let flexCenter =
    style([
      display(`flex),
      flexDirection(`column),
      alignItems(`flexStart),
    ]);

  let container =
    style([
      Theme.Typeface.monumentGrotesk,
      color(Css_Colors.white),
      display(`flex),
      flexDirection(`column),
      overflowX(`hidden),
      alignItems(`center),
      width(`percent(100.)),
      height(`percent(100.)),
      margin(`auto),
      padding2(~h=`rem(3.), ~v=`zero),
      paddingBottom(`rem(3.)),
    ]);

  let textContainer =
    merge([
      flexCenter,
      style([
        width(`percent(100.)),
        maxWidth(`rem(34.)),
        marginTop(`rem(6.25)),
        selector(
          "p,li,span",
          [fontSize(`rem(1.125)), lineHeight(`rem(1.75))],
        ),
        selector(
          "h1",
          [
            fontWeight(`num(540)),
            fontSize(`rem(3.)),
            lineHeight(`rem(3.625)),
            marginBottom(`rem(1.)),
          ],
        ),
        selector(
          "h2",
          [
            fontWeight(`num(530)),
            fontSize(`rem(2.5)),
            lineHeight(`rem(3.)),
            marginBottom(`rem(1.)),
          ],
        ),
      ]),
    ]);

  let background =
    style([
      width(`percent(100.)),
      height(`rem(180.)),
      backgroundColor(Theme.Colors.digitalBlack),
      backgroundSize(`cover),
      backgroundImage(`url("/static/img/backgrounds/LeadGen.jpg")),
    ]);

  let logo =
    style([width(`percent(100.)), height(`auto), marginTop(`rem(6.))]);

  let link = style([color(Theme.Colors.orange), cursor(`pointer)]);

  let seperator =
    style([
      textTransform(`uppercase),
      display(`flex),
      alignItems(`center),
      textAlign(`center),
      width(`percent(100.)),
      marginBottom(`rem(1.)),
      letterSpacing(`rem(0.05)),
      fontSize(`rem(0.875)),
      selector(
        "::before,::after",
        [
          contentRule(""),
          flex(`num(1.)),
          borderBottom(`px(1), `solid, white),
          marginLeft(`rem(1.)),
          marginRight(`rem(1.)),
        ],
      ),
    ]);

  let dashedSeperator =
    style([
      position(`relative),
      display(`flex),
      alignItems(`center),
      width(`percent(100.)),
      borderBottom(`px(1), `dashed, Theme.Colors.white),
      color(Theme.Colors.white),
      marginTop(`rem(0.7)),
      marginBottom(`rem(0.25)),
      before([
        contentRule("\\25CF"),
        position(`absolute),
        display(`flex),
        alignItems(`center),
        margin(`auto),
        left(`px(-2)),
      ]),
      after([
        contentRule("\\25CF"),
        position(`absolute),
        display(`flex),
        alignItems(`center),
        margin(`auto),
        right(`px(-2)),
      ]),
    ]);

  let releaseContainer =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      alignItems(`center),
      width(`percent(100.)),
      marginTop(`rem(1.125)),
      letterSpacing(`rem(0.01)),
      selector("> div:last-child", [marginTop(`rem(2.))]),
      media(
        Theme.MediaQuery.notMobile,
        [
          flexDirection(`row),
          selector("> div:last-child", [marginTop(`zero)]),
        ],
      ),
    ]);

  let release =
    style([
      textTransform(`uppercase),
      display(`flex),
      flexDirection(`column),
      justifyContent(`center),
      alignItems(`center),
      width(`percent(100.)),
      media(Theme.MediaQuery.notMobile, [width(`percent(40.))]),
      selector("div,span", [fontSize(`rem(0.875))]),
    ]);

  let releaseDates =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      alignItems(`center),
      width(`percent(100.)),
    ]);
};

[@react.component]
let make = () => {
  <Page title="Testworld" showFooter=false darkTheme=true>
    <div className=Styles.page>
      <div className=Styles.background>
        <div className=Styles.container>
          <div>
            <img
              className=Styles.logo
              src="/static/img/logos/LogoTestWorld.svg"
            />
          </div>
          <div className=Styles.textContainer> <SignUpWidget /> </div>
          <div className=Styles.textContainer>
            <h1> {React.string("Welcome to Testworld")} </h1>
            <p>
              {React.string(
                 "Get ready to join Mina's adversarial testnet, Testworld, starting later this year. In contrast to Mina's regular testnet, Testworld is where you will compete with others to maximize the amount of tokens earned, find critical bugs, and push the boundaries of the network in order to make Mina as secure as possible for mainnet.",
               )}
            </p>
          </div>
          <div className=Styles.textContainer>
            <h2> {React.string("How Testworld works")} </h2>
            <p>
              {React.string(
                 "To ensure the security of the protocol prior to mainnet, Mina is offering 1% of the total token supply as well as USD in rewards, which you can win by:",
               )}
            </p>
            <ul className=Css.(style([marginLeft(`rem(1.))]))>
              <li> {React.string("Uncovering vulnerabilities")} </li>
              <li> {React.string("Accruing testnet tokens")} </li>
              <li>
                {React.string(
                   "Scoring high points on the testnet leaderboard",
                 )}
              </li>
            </ul>
            <p className=Css.(style([marginTop(`rem(3.))]))>
              {React.string(
                 "In addition, the Mina Foundation will be delegating tokens reserved for future grants to participants who score top points for reliability and block production once mainnet is live.",
               )}
            </p>
          </div>
          <div className=Styles.textContainer>
            <h2> {React.string("Genesis Token Grant")} </h2>
            <span className=Css.(style([marginTop(`rem(1.))]))>
              {React.string(
                 "Testworld will be the last phase of Mina's testnet for community members to qualify for the ",
               )}
              <Next.Link href="/genesis">
                <span className=Styles.link>
                  {React.string("Genesis token grant ")}
                </span>
              </Next.Link>
              {React.string(
                 "before mainnet launches. There are up to 800 Genesis grants still available, and Genesis grant recipients, otherwise known as Genesis Founding Members (GFMs), will each receive 66,000 tokens. ",
               )}
              <Next.Link href="/genesis">
                <span className=Styles.link>
                  {React.string("Apply for Genesis now. ")}
                </span>
              </Next.Link>
            </span>
            <span className=Css.(style([marginTop(`rem(2.))]))>
              {React.string(
                 "Prepare to engage in Testworld and we'll see you later this year.",
               )}
            </span>
          </div>
          <div className=Styles.textContainer> <SignUpWidget /> </div>
        </div>
      </div>
    </div>
  </Page>;
};
