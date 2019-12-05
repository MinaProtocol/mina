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
      media("(min-width: 60rem)", [display(`flex), marginLeft(`rem(1.))]),
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
        textAlign(`left),
        color(Style.Colors.midnight),
      ]),
    ]);

  let heroHeading = merge([Style.H1.hero, style([marginTop(`rem(1.53))])]);

  let heroCopy =
    merge([
      Style.Body.basic,
    ]);
    
  let heroH3 = 
    merge([
      Style.H3.basic,
      style([textAlign(`left), fontWeight(`normal),color(Style.Colors.midnight)]),
    ])

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
        <Spacer height=1./>
        <p className=Styles.heroCopy>
          {React.string(
            "Coda makes it dead simple for node operators, developers, and entrepreneurs to use cryptocurrencies. Deploy nodes, write code, and access your funds on full nodes that can live anywhere -- in your phone, or even in a web browser."
           )}
        </p>
        <p className=Styles.heroCopy>
        {React.string("Coda is 100% open-source, built for and by community members like yourself. Find resources below on how to join the network as a node operator, begin contributing code, and stay up to date on developer tooling and grants.")}
        </p> 
         <Spacer height=1./>
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
          href="https://docs.google.com/forms/d/e/1FAIpQLSc1obbB_0ON8Ptfhc56jZ_NfwzxhmNtMuVuLNDqoO8Y46eWiw/viewform?usp=sf_link"
        />
      </div>
    </div>
  </div>;
};
