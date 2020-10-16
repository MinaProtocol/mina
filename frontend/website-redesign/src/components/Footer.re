module Styles = {
  open Css;
  let footerContainer =
    style([
      position(`relative),
      left(`zero),
      bottom(`zero),
      height(`rem(106.)),
      padding2(~v=`rem(4.), ~h=`rem(1.25)),
      backgroundImage(`url("/static/img/Small.jpg")),
      backgroundSize(`cover),
      media(
        Theme.MediaQuery.tablet,
        [
          padding2(~v=`rem(4.), ~h=`rem(2.68)),
          height(`rem(75.)),
          backgroundImage(`url("/static/img/Medium.jpg")),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          padding2(~v=`rem(5.5), ~h=`rem(9.5)),
          height(`auto),
          backgroundImage(`url("/static/img/Large.jpg")),
        ],
      ),
    ]);
  let backToTopButton =
    style([
      position(`fixed),
      right(`rem(1.2)),
      bottom(`rem(1.2)),
      media(
        Theme.MediaQuery.tablet,
        [right(`rem(2.5)), bottom(`rem(3.375))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [right(`rem(1.75)), bottom(`rem(1.75))],
      ),
    ]);
  let backToTopButtonContent =
    style([
      display(`flex),
      height(`rem(2.62)),
      flexDirection(`column),
      alignItems(`center),
      justifyContent(`spaceBetween),
      color(white),
    ]);

  let innerContainer =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      media(Theme.MediaQuery.desktop, [flexDirection(`row)]),
    ]);

  let whiteLine =
    style([
      border(`px(1), `solid, white),
      marginTop(`rem(3.0)),
      width(`percent(100.)),
      opacity(0.2),
      marginBottom(`rem(0.)),
    ]);
};

module SocialIcons = {
  module Styles = {
    open Css;
    let iconsRow =
      style([
        display(`flex),
        flexDirection(`row),
        justifyContent(`spaceBetween),
        alignContent(`center),
        width(`rem(14.)),
        height(`rem(2.)),
        color(white),
        selector(
          "a",
          [
            width(`rem(2.)),
            color(white),
            hover([color(Theme.Colors.orange)]),
          ],
        ),
      ]);

    let anchor = style([textDecoration(`none)]);
  };

  [@react.component]
  let make = () => {
    <div className=Styles.iconsRow>
      <a className=Styles.anchor href="https://bit.ly/MinaDiscord">
        <Icon kind=Icon.Discord size=2. />
      </a>
      <a className=Styles.anchor href="https://twitter.com/minaprotocol">
        <Icon kind=Icon.Twitter size=2. />
      </a>
      <a className=Styles.anchor href="http://bit.ly/MinaProtocolFacebook">
        <Icon kind=Icon.Facebook size=2. />
      </a>
      <a className=Styles.anchor href="http://bit.ly/MinaTelegram">
        <Icon kind=Icon.Telegram size=2. />
      </a>
      <a
        className=Styles.anchor
        href="https://forums.codaprotocol.com/t/coda-protocol-chinese-resources/200">
        <Icon kind=Icon.WeChat size=2. />
      </a>
    </div>;
  };
};

module LeftSide = {
  module Styles = {
    open Css;
    let leftSide =
      style([
        display(`flex),
        flexDirection(`column),
        justifyContent(`flexStart),
        alignContent(`spaceBetween),
        media(Theme.MediaQuery.desktop, [marginRight(`rem(10.6))]),
      ]);

    let emailInputSection =
      style([
        marginTop(`rem(4.)),
        media(Theme.MediaQuery.desktop, [marginTop(`rem(10.3))]),
      ]);

    let logo = style([height(`rem(3.1)), width(`rem(11.))]);

    let label =
      merge([Theme.Type.h4, style([color(white), lineHeight(`rem(2.))])]);

    let emailSubtext =
      merge([
        Theme.Type.paragraph,
        style([
          lineHeight(`rem(1.63)),
          color(white),
          opacity(0.7),
          marginTop(`zero),
          marginBottom(`rem(1.)),
        ]),
      ]);
  };

  [@react.component]
  let make = () => {
    <div className=Styles.leftSide>
      <img
        src="/static/svg/footerLogo.svg"
        alt="Mina Logo"
        className=Styles.logo
      />
      <div className=Styles.emailInputSection>
        <div className=Styles.label> {React.string("Get Updates")} </div>
        <p className=Styles.emailSubtext>
          {React.string("Mina is growing fast! Subscribe to stay updated")}
        </p>
        <EmailInput />
        <Spacer height=2. />
        <div className=Styles.label> {React.string("Connect")} </div>
        <p className=Styles.emailSubtext>
          {React.string("Join the conversation.")}
        </p>
        <SocialIcons />
      </div>
    </div>;
  };
};

module Subfooter = {
  module Styles = {
    open Css;
    let column =
      style([
        display(`flex),
        flexDirection(`column),
        width(`rem(21.)),
        height(`rem(14.4)),
        media(Theme.MediaQuery.tablet, [height(`rem(3.75))]),
        media(
          Theme.MediaQuery.desktop,
          [
            justifyContent(`spaceBetween),
            width(`percent(100.)),
            height(`rem(1.4)),
            marginTop(`rem(1.5)),
            flexDirection(`rowReverse),
          ],
        ),
      ]);
    let smallLinks =
      merge([
        Theme.Type.navLink,
        style([
          fontSize(`px(14)),
          color(white),
          textDecoration(`none),
          marginTop(`rem(1.5)),
          media(Theme.MediaQuery.desktop, [marginTop(`zero)]),
        ]),
      ]);

    let linksContainer =
      style([
        display(`flex),
        flexDirection(`column),
        media(
          Theme.MediaQuery.tablet,
          [
            flexDirection(`row),
            justifyContent(`spaceBetween),
            alignContent(`center),
            width(`rem(39.3)),
            marginRight(`rem(5.25)),
          ],
        ),
      ]);

    let copyright =
      merge([
        Theme.Type.paragraphSmall,
        style([
          color(white),
          margin2(~v=`rem(1.5), ~h=`zero),
          opacity(0.6),
          media(Theme.MediaQuery.tablet, [marginBottom(`rem(0.))]),
          media(Theme.MediaQuery.desktop, [margin2(~v=`zero, ~h=`zero)]),
        ]),
      ]);
  };

  [@react.component]
  let make = () => {
    <div className=Styles.column>
      <div className=Styles.linksContainer>
        <a href="https://o1labs.org/" className=Styles.smallLinks>
          {React.string("O(1) Labs")}
        </a>
        <a
          href="https://github.com/MinaProtocol/mina/blob/develop/CODE_OF_CONDUCT.md"
          className=Styles.smallLinks>
          {React.string("Code of Conduct")}
        </a>
        <Next.Link href="/privacy">
          <a className=Styles.smallLinks>
            {React.string("Privacy Policy")}
          </a>
        </Next.Link>
        <Next.Link href="/tos">
          <a className=Styles.smallLinks>
            {React.string("Terms of Service")}
          </a>
        </Next.Link>
      </div>
      <p className=Styles.copyright>
        {React.string({js|©|js} ++ "2020 Mina. Started by O(1) Labs.")}
      </p>
    </div>;
  };
};

[@react.component]
let make = () => {
  <footer className=Styles.footerContainer>
    <div className=Styles.innerContainer> <LeftSide /> <FooterLinks /> </div>
    <hr className=Styles.whiteLine />
    <Subfooter />
    <div className=Styles.backToTopButton>
      <Button
        href=`Scroll_to_top
        height={`rem(4.125)}
        width={`rem(3.75)}
        bgColor=Theme.Colors.black
        borderColor=Theme.Colors.white
        paddingX=1.1
        paddingY=0.75
        dark=true>
        <div className=Styles.backToTopButtonContent>
          <Icon kind=Icon.ArrowUpMedium size=1. />
          {React.string("Top")}
        </div>
      </Button>
    </div>
  </footer>;
};
