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
        height(Spacing.headerHeight),
        maxHeight(Spacing.headerHeight),
        minHeight(Spacing.headerHeight),
        display(`flex),
        alignItems(`center),
        justifyContent(`spaceBetween),
        color(black),
        fontFamily("IBM Plex Sans, Sans-Serif"),
        padding2(~v=`zero, ~h=Theme.Spacing.defaultSpacing),
        borderBottom(`px(1), `solid, Colors.borderColor),
        CssElectron.appRegion(`drag),
      ]),
      notText,
    ]);

  let rightButtons =
    style([
      display(`flex),
      alignItems(`center),
      justifyContent(`spaceBetween),
    ]);
};

[@react.component]
let make = () =>
  <header className=Styles.header>
    <div
      style={ReactDOMRe.Style.make(~display="flex", ~alignItems="center", ())}>
      <div className=Theme.codaLogoCurrent />
      <p
        style={ReactDOMRe.Style.make(~fontWeight="100", ~fontSize="160%", ())}>
        {React.string({j|CODA|j})}
      </p>
    </div>
    <div className=Styles.rightButtons> 
      <Link onClick={_e => ReasonReact.Router.push("/settings")}>
        <Icon kind=Icon.Settings />
        <Spacer width={0.25} />
        {React.string("Settings")}
      </Link>
      <Spacer width={1.5} />
      <div
        style={ReactDOMRe.Style.make(
          ~fontWeight="500",
          ~color="#479056",
          ~marginRight="10px",
          ~padding="0.25em",
          ~paddingLeft="2em",
          ~paddingRight="2em",
          ~overflow="hidden",
          ~borderRadius="4px",
          ~background=
            {|repeating-linear-gradient(
                  to right,
                  transparent,
                  transparent 2px,
                  rgba(71, 144, 86, 0.3) 2px,
                  rgba(71, 144, 86, 0.3) 4px)|},
          (),
        )}>
        {ReasonReact.string({j|SYNCED 1.4s|j})}
      </div>
    </div>
  </header>;
