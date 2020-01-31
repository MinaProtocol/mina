let component = ReasonReact.statelessComponent("Header");

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

  let logo =
    style([
      display(`flex),
      alignItems(`center),
      marginLeft(`rem(4.)),
      marginTop(`rem(4.5)),
    ]);
};

[@react.component]
let make = () => {
  let codaSvg = Hooks.useAsset("CodaLogo.svg");
  <header className=Styles.header>
    <div className=Styles.logo> <img src=codaSvg alt="Coda logo" /> </div>
  </header>;
};
