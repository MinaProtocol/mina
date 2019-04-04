let component = ReasonReact.statelessComponent("Header");

module Styles = {
  open Css;
  open StyleGuide;
  let header =
    merge([
      style([
        height(`em(4.)),
        maxHeight(`em(4.)),
        minHeight(`em(4.)),
        display(`flex),
        alignItems(`center),
        justifyContent(`spaceBetween),
        backgroundColor(Colors.headerBgColor),
        color(white),
        fontFamily("IBM Plex Sans, Sans-Serif"),
        paddingLeft(`px(20)),
        CssElectron.appRegion(`drag),
      ]),
      notText,
    ]);
};
let make = _children => {
  ...component,
  render: _self =>
    <div className=Styles.header>
      <div
        style={ReactDOMRe.Style.make(
          ~display="flex",
          ~alignItems="center",
          (),
        )}>
        <div className=StyleGuide.codaLogoCurrent />
        <p
          style={ReactDOMRe.Style.make(
            ~fontWeight="100",
            ~fontSize="160%",
            (),
          )}>
          {ReasonReact.string({j|CODA|j})}
        </p>
      </div>
      <p style={ReactDOMRe.Style.make(~color="#516679", ())}>
        {ReasonReact.string({j|Master @B37CF8 |j})}
      </p>
      <p style={ReactDOMRe.Style.make(~color="#516679", ())}>
        {ReasonReact.string({j|Seed IP|j})}
      </p>
      <select
        style={ReactDOMRe.Style.make(
          ~padding="10px",
          ~background="#17212d",
          ~color="#4789c4",
          ~border="2px solid #2a3f58",
          ~outline="none",
          ~fontWeight="500",
          ~width="11em",
          ~height="2em",
          (),
        )}>
        <option value="testnet"> {ReasonReact.string("Testnet")} </option>
        <option value="network2"> {ReasonReact.string("Network 2")} </option>
        <option value="network3"> {ReasonReact.string("Network 3")} </option>
      </select>
      <div
        style={ReactDOMRe.Style.make(
          ~padding="10px",
          ~fontSize="180%",
          ~color="#516679",
          ~fontWeight="bold",
          ~transform="rotate(-45deg)",
          (),
        )}>
        {ReasonReact.string({js|⚲|js})}
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
    </div>,
};
