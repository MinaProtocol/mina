let component = ReasonReact.statelessComponent("Header");
[@bs.scope "window"] [@bs.val] external openExternal: string => unit = "openExternal";

module Styles = {
  open Css;
  open Theme;

  let header =
    merge([
      style([
        position(`fixed),
        top(`px(0)),
        left(`px(0)),
        right(`px(0)),
        zIndex(101),
        marginLeft(`rem(4.)),
        marginRight(`rem(4.)),
        marginTop(`rem(4.5)),
        height(Spacing.headerHeight),
        maxHeight(Spacing.headerHeight),
        minHeight(Spacing.headerHeight),
        display(`flex),
        alignItems(`center),
        justifyContent(`spaceBetween),
        color(black),
        fontFamily("IBM Plex Sans, Sans-Serif"),
        padding2(~v=`zero, ~h=Theme.Spacing.defaultSpacing),
        CssElectron.appRegion(`drag),
      ]),
      notText,
    ]);

  let logo = style([display(`flex), alignItems(`center)]);

  let helpContainer =
    style([
      display(`flex),
      alignItems(`center),
      justifyContent(`flexEnd),
      width(`rem(20.)),
    ]);

  let helpText =
    merge([style([color(white)]), Theme.Text.Body.regularSmall]);
};

module HelpSection = {
  [@react.component]
  let make = () => {
    <div className=Styles.helpContainer>
      <p className=Styles.helpText> {React.string("Need help?")} </p>
      <Spacer width=1. />
      <HelpButton
        label="Docs"
        icon=HelpIcon.Docs
        width=4.
        height=1.5
        padding=0.4625
        style=Button.OffWhite
        onClick={_ => openExternal("https://codaprotocol.com/docs/")}
      />
      <Spacer width=0.37 />
      <HelpButton
        label="Discord"
        icon=HelpIcon.Discord
        width=5.5
        height=1.5
        padding=0.4625
        style=Button.OffWhite
        onClick={_ => openExternal("https://discordapp.com/invite/Vexf4ED")}
      />
    </div>;
  };
};

[@react.component]
let make = () => {
  let codaSvg = Hooks.useAsset("CodaLogoWhite.png");
  <header className=Styles.header>
    <div className=Styles.logo> <img src=codaSvg alt="Coda logo" /> </div>
    <HelpSection />
  </header>;
};
