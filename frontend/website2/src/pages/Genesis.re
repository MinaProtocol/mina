module Styles = {
  open Css;
  let page =
    style([
      marginLeft(`auto),
      marginRight(`auto),
      media(Theme.MediaQuery.tablet, [maxWidth(`rem(68.))]),
    ]);

  let lineBreak =
    style([
      height(px(2)),
      borderTop(px(1), `dashed, Theme.Colors.marine),
      borderLeft(`zero, solid, transparent),
      borderBottom(px(1), `dashed, Theme.Colors.marine),
    ]);

  let heroImage =
    style([
      display(`none),
      media(
        Theme.MediaQuery.tablet,
        [display(`flex), marginLeft(`rem(1.))],
      ),
    ]);

  let header =
    style([
      display(`flex),
      flexDirection(`column),
      width(`percent(100.)),
      color(Theme.Colors.saville),
      textAlign(`center),
      margin2(~v=rem(3.5), ~h=`zero),
    ]);

  let heroRow =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      alignItems(`center),
      media(Theme.MediaQuery.tablet, [flexDirection(`row)]),
    ]);

  let heroText =
    merge([
      header,
      style([
        maxWidth(`px(500)),
        marginLeft(`zero),
        textAlign(`left),
        color(Theme.Colors.midnight),
      ]),
    ]);

  let heroHeading = merge([Theme.H1.hero, style([marginTop(`rem(1.53))])]);

  let heroCopy = merge([Theme.Body.basic]);

  let heroH3 =
    merge([
      Theme.H3.basic,
      style([
        textAlign(`left),
        fontWeight(`normal),
        color(Theme.Colors.midnight),
      ]),
    ]);

  let ctaButton =
    merge([
      Theme.Body.basic_semibold,
      style([
        width(`rem(14.)),
        height(`rem(3.)),
        backgroundColor(Theme.Colors.hyperlink),
        borderRadius(`px(6)),
        textDecoration(`none),
        color(white),
        padding2(~v=`px(12), ~h=`px(24)),
        textAlign(`center),
        alignSelf(`center),
        hover([backgroundColor(Theme.Colors.hyperlinkHover)]),
        media(
          Theme.MediaQuery.tablet,
          [marginLeft(`rem(0.)), alignSelf(`flexStart)],
        ),
      ]),
    ]);

  let buttonRow =
    style([
      display(`grid),
      gridTemplateColumns([`repeat((`num(1), `rem(21.25)))]),
      gridTemplateRows([`repeat((`num(1), `rem(14.25)))]),
      media(
        Theme.MediaQuery.tablet,
        [
          gridTemplateColumns([`repeat((`num(2), `rem(23.8)))]),
          gridTemplateRows([`repeat((`num(2), `rem(12.5)))]),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          gridTemplateColumns([`repeat((`num(2), `rem(32.5)))]),
          gridTemplateRows([`repeat((`num(2), `rem(11.5)))]),
        ],
      ),
      gridRowGap(rem(2.5625)),
      gridColumnGap(rem(3.)),
      justifyContent(`center),
      marginLeft(`auto),
      marginRight(`auto),
      marginTop(rem(5.18)),
      marginBottom(rem(3.)),
    ]);
};

[@react.component]
let make = () => {
  <Page>
    <Wrapped>
      <div className=Styles.page>
        <div className=Styles.heroRow>
          <div className=Styles.heroText>
            <h1 className=Styles.heroHeading> {React.string("Genesis")} </h1>
            <Spacer height=1. />
            <p className=Styles.heroCopy>
              {React.string(
                 "Become one of 1000 community members to receive a grant of 66,000 pre-mainnet tokens on Coda. You'll complete challenges on testnet, learn how to operate the protocol, receive public recognition on our leaderboard and help to strengthen the Coda network and community.",
               )}
            </p>
            <Spacer height=1. />
            <a href="/docs/getting-started" className=Styles.ctaButton>
              {React.string({js| Apply Now |js})}
            </a>
          </div>
          <img
            src="/static/img/genesishero.png"
            alt="Genesis Program hero image with a light blue theme."
            className=Styles.heroImage
          />
        </div>
        <br />
        <hr className=Styles.lineBreak />
        <div>
          <div className=Styles.buttonRow>
            <HoverCard
              heading={React.string({js| Testnet Docs |js})}
              text={React.string(
                "Learn how to install Coda and connect to the network.",
              )}
              href="/docs/getting-started"
            />
            <HoverCard
              heading={React.string({js| Grants |js})}
              text={React.string(
                "Receive funding to work on Coda related projects and research.",
              )}
              href="https://github.com/CodaProtocol/coda-grants"
            />
            <HoverCard
              heading={React.string({js| Developer Docs |js})}
              text={React.string(
                "Contribute to Coda source code and core products.",
              )}
              href="/docs/developers"
            />
            // TODO: Put SDK waitlist link here
            <HoverCard
              heading={React.string({js| Coda SDK |js})}
              text={React.string(
                "Sign up for the Coda SDK waitlist to integrate digital payments into your app.",
              )}
              href="https://docs.google.com/forms/d/e/1FAIpQLSc1obbB_0ON8Ptfhc56jZ_NfwzxhmNtMuVuLNDqoO8Y46eWiw/viewform?usp=sf_link"
            />
          </div>
        </div>
      </div>
    </Wrapped>
  </Page>;
};
