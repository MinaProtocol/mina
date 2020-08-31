module Styles = {
  open Css;
  let footerContainer =
    style([
      left(`zero),
      bottom(`zero),
      width(`percent(100.)),
      height(`rem(106.)),
      display(`flex),
      flexDirection(`column),
      padding2(~v=`rem(4.), ~h=`rem(1.25)),
      backgroundImage(`url("/static/img/FooterBackground.png")),
      media(
        Theme.MediaQuery.tablet,
        [padding2(~v=`rem(5.5), ~h=`rem(9.5)), height(`rem(49.))],
      ),
    ]);
  let innerContainer =
    style([media(Theme.MediaQuery.desktop, [flexDirection(`row)])]);
  let logo =
    style([
      height(`rem(3.1)),
      width(`rem(11.)),
      marginBottom(`rem(4.)),
    ]);
  let label = merge([Theme.Type.h4, style([color(white)])]);
  let connectLabel =
    merge([Theme.Type.h4, style([color(white), marginTop(`rem(2.12))])]);
  let paragraph = merge([Theme.Type.paragraph, style([color(white)])]);
  let emailSubtext =
    merge([
      Theme.Type.paragraph,
      style([color(white), marginTop(`zero), marginBottom(`px(8))]),
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
        width(`rem(17.)),
        height(`rem(6.1)),
        color(white),
      ]);
  };
  [@react.component]
  let make = () => {
    <div className=Styles.iconsRow>
      <Icon kind=Icon.Discord size=2. />
      <Icon kind=Icon.Twitter size=2. />
      <Icon kind=Icon.Facebook size=2. />
      <Icon kind=Icon.Telegram size=2. />
      <Icon kind=Icon.WeChat size=2. />
    </div>;
  };
};

module FooterLinks = {
  module Styles = {
    open Css;
    let linksGrid =
      style([
        display(`grid),
        gridTemplateColumns([`rem(10.), `rem(10.)]),
        gridTemplateRows([`rem(15.), `rem(15.), `rem(15.)]),
      ]);
    let linksGroup =
      style([
        display(`flex),
        width(`rem(15.)),
        height(`rem(10.)),
        flexDirection(`column),
      ]);
    let linkStyle = merge([Theme.Type.navLink, style([color(white)])]);
  };
  [@react.component]
  let make = () => {
    <div>
      <div className=Styles.linksGroup>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Link 1")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Link 1")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Link 1")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Link 1")} </a>
        </Next.Link>
        <Next.Link href="">
          <a className=Styles.linkStyle> {React.string("Link 1")} </a>
        </Next.Link>
      </div>
    </div>;
  };
};

module LeftSide = {
  [@react.component]
  let make = () => {
    <>
      <img
        src="/static/svg/footerLogo.svg"
        alt="Mina Logo"
        className=Styles.logo
      />
      <div className=Styles.label> {React.string("Get Updates")} </div>
      <p className=Styles.emailSubtext>
        {React.string("Mina's growing fast! Sign up and stay in the loop.")}
      </p>
      <EmailInput />
      <div className=Styles.connectLabel> {React.string("Connect")} </div>
      <p className=Styles.emailSubtext>
        {React.string("Join the conversation.")}
      </p>
      <SocialIcons />
    </>;
  };
};
[@react.component]
let make = () => {
  <div className=Styles.footerContainer>
    <div className=Styles.innerContainer> <LeftSide /> <FooterLinks /> </div>
  </div>;
};
