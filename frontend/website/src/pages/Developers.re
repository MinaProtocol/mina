module Styles = {
  open Css;
  let page =
    style([
      marginLeft(`auto),
      marginRight(`auto),
      media(Theme.MediaQuery.tablet, [maxWidth(`rem(50.66))]),
      media(Theme.MediaQuery.desktop, [maxWidth(`rem(68.))]),
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

let description = "Coda is 100% open-source, built for and by community members like yourself. Find resources on how to join the network as a node operator, begin contributing code, and stay up to date on developer tooling and grants.";

[@react.component]
let make = () => {
  <Page title="Coda Developer Portal" description>
    <Wrapped>
      <div className=Styles.page>
        <div className=Styles.heroRow>
          <div className=Styles.heroText>
            <h1 className=Styles.heroHeading>
              {React.string("Coda Developer Portal")}
            </h1>
            <Spacer height=1. />
            <p className=Styles.heroCopy>
              {React.string(
                 "Coda makes it dead simple for node operators, developers, and entrepreneurs to use cryptocurrencies. Deploy nodes, write code, and access your funds on full nodes that can live anywhere -- in your phone, or even in a web browser.",
               )}
            </p>
            <p className=Styles.heroCopy>
              {React.string(
                 "Coda is 100% open-source, built for and by community members like yourself. Find resources below on how to join the network as a node operator, begin contributing code, and stay up to date on developer tooling and grants.",
               )}
            </p>
            <Spacer height=1. />
            <a href="/docs/getting-started" className=Styles.ctaButton>
              {React.string({js| Get Started →|js})}
            </a>
          </div>
          <Svg
            link="/static/img/Developers.svg"
            dims=(29.75, 25.76)
            alt="Collage of developer images"
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
