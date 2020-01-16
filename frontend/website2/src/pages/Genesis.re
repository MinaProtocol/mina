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

  let heroHeading =
    merge([
      Theme.H1.hero,
      style([fontWeight(`semiBold), marginTop(`rem(1.53))]),
    ]);

  let heroCopy = merge([Theme.Body.basic]);

  let heroH3 =
    merge([
      Theme.H3.basic,
      style([
        textAlign(`left),
        fontWeight(`semiBold),
        color(Theme.Colors.marine),
      ]),
    ]);

  let ctaButton =
    merge([
      Theme.Body.basic_semibold,
      style([
        width(`rem(14.)),
        height(`rem(3.)),
        backgroundColor(Theme.Colors.clover),
        borderRadius(`px(6)),
        textDecoration(`none),
        color(white),
        padding2(~v=`px(12), ~h=`px(24)),
        textAlign(`center),
        alignSelf(`center),
        hover([backgroundColor(Theme.Colors.jungle)]),
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

  let whitePaperButtonRow =
    style([
      display(`grid),
      gridTemplateColumns([`percent(100.)]),
      gridTemplateRows([auto]),
      gridRowGap(`rem(0.7)),
      media(
        Theme.MediaQuery.notMobile,
        [display(`flex), flexDirection(`row)],
      ),
    ]);

  let textBlock = style([maxWidth(`rem(43.75)), width(`percent(100.))]);
  let textBlockHeading =
    style([
      Theme.Typeface.ibmplexsans,
      color(Theme.Colors.marine),
      fontWeight(`medium),
      fontSize(`rem(2.)),
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
            <Spacer height=2. />
            <h3 className=Styles.heroH3>
              {React.string(
                 "Become one of 1000 community members to receive a grant of 66,000 pre-mainnet tokens on Coda.",
               )}
            </h3>
            <Spacer height=1. />
            <p className=Styles.heroCopy>
              {React.string(
                 "You'll complete challenges on testnet, learn how to operate the protocol, receive public recognition on our leaderboard and help to strengthen the Coda network and community.",
               )}
            </p>
            <Spacer height=2. />
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
        <Spacer height=3. />
        <h1 className=Styles.textBlockHeading>
          {React.string("Become a Genesis Founding Member")}
        </h1>
        <div className=Styles.textBlock>
          <p className=Styles.heroCopy>
            {React.string(
               "Becoming a Genesis founding member is the highest honor in the Coda community.
             You'll have an opportunity to strengthen and harden the protocol, create tooling
              and documentation and build the community.",
             )}
          </p>
          <Spacer height=1. />
          <p className=Styles.heroCopy>
            {React.string(
               "When the protocol launches in mainnet, you will be the backbone of robust,
             decentralized participation. Together, we will enable the first blockchain
             that is truly decentralized at scale. ",
             )}
          </p>
        </div>
        <hr className=Styles.lineBreak />
        <div className=Styles.whitePaperButtonRow>
          <WhitepaperButton
            label="Technical whitepaper"
            sigil=Icons.technical
          />
          <Spacer width=2.5 />
          <WhitepaperButton label="Economic whitepaper" sigil=Icons.economic />
        </div>
      </div>
    </Wrapped>
  </Page>;
};
