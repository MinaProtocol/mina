let component = ReasonReact.statelessComponent("Header");

module Styles = {
  open Css;
  open StyleGuide;
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
        backgroundColor(Colors.headerBgColor),
        color(black),
        fontFamily("IBM Plex Sans, Sans-Serif"),
        paddingLeft(`px(20)),
        borderBottom(`px(1), `solid, rgba(0, 0, 0, 0.15)),
        CssElectron.appRegion(`drag),
      ]),
      notText,
    ]);
};

[@react.component]
let make = () =>
  <div className=Styles.header>
    <div
      style={ReactDOMRe.Style.make(~display="flex", ~alignItems="center", ())}>
      <div className=StyleGuide.codaLogoCurrent />
      <p
        style={ReactDOMRe.Style.make(~fontWeight="100", ~fontSize="160%", ())}>
        {ReasonReact.string({j|CODA|j})}
      </p>
    </div>
    <div
      style={ReactDOMRe.Style.make(
        ~fontWeight="500",
        // ~height="1em",
        ~color="#c49d41",
        ~marginRight="10px",
        ~padding="0.25em",
        ~paddingLeft="2em",
        ~paddingRight="2em",
        ~borderRadius="4px",
        ~border="2px solid #60542c",
        ~background=
          {|repeating-linear-gradient(
                to right,
                transparent,
                transparent 2px,
                #60542c 2px,
                #60542c 4px)|},
        (),
      )}>
      {ReasonReact.string({j|Syncing|j})}
    </div>
  </div>;
