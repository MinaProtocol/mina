let extraHeaders = <> Head.legacyStylesheets </>;

Css.global("#block-explorer div div a", [Css.display(`none)]);
Css.global("#block-explorer div h2", [Css.display(`none)]);

let component = ReasonReact.statelessComponent("Testnet");
let make = _ => {
  ...component,
  render: _self =>
    <div>
      <h3
        className=Css.(
          merge([
            Style.H3.wings,
            style([marginTop(`rem(4.0)), marginBottom(`rem(4.0))]),
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
    </div>,
};
