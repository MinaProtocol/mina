module Styles = {
  open Css;
  let page =
    style([
      marginLeft(`auto),
      marginRight(`auto),
      media("(min-width: 60rem)", [maxWidth(`rem(50.66))]),
      media("(min-width: 105rem)", [maxWidth(`rem(68.))]),
    ]);

  let lineBreak =
    style([
      height(px(2)),
      borderTop(px(1), `dashed, Style.Colors.marine),
      borderLeft(`zero, solid, transparent),
      borderBottom(px(1), `dashed, Style.Colors.marine),
    ]);

  let heroImage =
    style([
      display(`none),
      media("(min-width: 60rem)", [display(`flex)]),
    ]);

  let header =
    style([
      display(`flex),
      flexDirection(`column),
      width(`percent(100.)),
      color(Style.Colors.saville),
      textAlign(`center),
      margin2(~v=rem(3.5), ~h=`zero),
    ]);

  let heroRow =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      alignItems(`center),
      media("(min-width: 60rem)", [flexDirection(`row)]),
    ]);

  let heroText =
    merge([
      header,
      style([
        maxWidth(`px(500)),
        marginLeft(`zero),
        media("(min-width: 60rem)", [marginLeft(`rem(2.1875))]),
        textAlign(`left),
        color(Style.Colors.midnight),
      ]),
    ]);

  let heroHeading = merge([Style.H1.hero, style([marginTop(`rem(1.53))])]);

  let heroCopy =
    merge([
      Style.Body.basic,
      style([marginTop(`rem(3.)), marginBottom(`rem(3.375))]),
    ]);

  let ctaButton =
    merge([
      Style.Body.basic_semibold,
      style([
        width(`rem(14.)),
        height(`rem(3.)),
        backgroundColor(Style.Colors.hyperlink),
        borderRadius(`px(6)),
        textDecoration(`none),
        color(white),
        padding2(~v=`px(12), ~h=`px(24)),
        textAlign(`center),
        alignSelf(`center),
        media("(min-width: 60rem)", [marginLeft(`rem(0.)), alignSelf(`flexStart)]),
      ]),
    ]);

  let buttonRow =
    style([
      display(`grid),
      gridTemplateColumns([`repeat((`num(1), `rem(21.25)))]),
      gridTemplateRows([`repeat((`num(1), `rem(14.25)))]),
      media(
        "(min-width: 60rem)",
        [
          gridTemplateColumns([`repeat((`num(2), `rem(23.8)))]),
          gridTemplateRows([`repeat((`num(2), `rem(12.5)))]),
        ],
      ),
      media(
        "(min-width: 105rem)",
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
  <div className=Styles.page>
    <div className=Styles.heroRow>
      <div className=Styles.heroText>
        <h1 className=Styles.heroHeading>
          {React.string("Coda Developer Portal")}
        </h1>
        <p className=Styles.heroCopy>
          {React.string(
             "We're an open-source community of engineers, cryptographers, researchers, and dreamers. Help us build the first succinct blockchain.",
           )}
        </p>
        <a href="/docs/getting-started/" className=Styles.ctaButton>
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
          href="/docs/getting-started/"
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
          href="/docs/developers/"
        />
        // TODO: Put SDK waitlist link here
        <HoverCard
          heading={React.string({js| Coda SDK |js})}
          text={React.string(
            "Sign up for the Coda SDK waitlist to integrate digital payments into your app.",
          )}
          href="https://docs.google.com/forms/d/e/1FAIpQLScQRGW0-xGattPmr5oT-yRb9aCkPE6yIKXSfw1LRmNx1oh6AA/viewform"
        />
      </div>
    </div>
  </div>;
};
