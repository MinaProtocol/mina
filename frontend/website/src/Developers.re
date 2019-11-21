module Styles = {
  open Css;
  let page =
    style([
      marginLeft(`auto),
      marginRight(`auto),
      maxWidth(`rem(22.43)),
      media("(min-width: 60rem)", [maxWidth(`rem(50.66)),]),
      media("(min-width: 105rem)", [maxWidth(`rem(66.5))]),
    ]);

  let lineBreak =
    style([
      height(px(4)),
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
      color(Style.Colors.slate),
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
    merge([header, style([maxWidth(`px(500)), textAlign(`left)])]);

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
      gridRowGap(rem(2.625)),
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
        <h1 className=Style.H1.hero>
          {React.string("Coda Developer Portal")}
        </h1>
        <p className=Style.Body.basic>
          {React.string(
             "We're an open-source community of engineers, cryptographers, researchers, and dreamers. Help us build the first succinct blockchain.",
           )}
        </p>
        <br />
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
