let extraHeaders = <> Head.legacyStylesheets </>;

// Hide social links
Css.global("#block-explorer div div a.no-underline", [Css.display(`none)]);
// Hide header text
Css.global("#block-explorer div h2", [Css.display(`none)]);
// Make everything IBM plex sans
Css.global(".roboto", [Style.Typeface.ibmplexsans]);
Css.global("div", [Style.Typeface.ibmplexsans]);

let component = ReasonReact.statelessComponent("Testnet");
let make = _ => {
  ...component,
  render: _self =>
    <section
      className=Css.(
        style([media(Style.MediaQuery.full, Style.paddingX(`rem(8.0)))])
      )>
      <h3
        className=Css.(
          merge([
            Style.H3.wings,
            style([marginTop(`rem(3.0)), marginBottom(`rem(3.0))]),
          ])
        )>
        {ReasonReact.string("Testnet")}
      </h3>
      <div
        className=Css.(
          style([
            marginLeft(`auto),
            marginRight(`auto),
            marginTop(`rem(8.0)),
          ])
        )
        id="block-explorer"
      />
      <script defer=true src="/static/main.bc.js" />
    </section>,
};
