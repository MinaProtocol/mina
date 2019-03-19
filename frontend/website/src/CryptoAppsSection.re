module Code = {
  let component = ReasonReact.statelessComponent("CryptoAppsSection.Code");
  let make = (~src, _children) => {
    ...component,
    render: _self =>
      <pre
        className=Css.(
          style(
            Style.paddingX(`rem(0.5))
            @ Style.paddingY(`rem(1.0))
            @ [
              backgroundColor(Style.Colors.navy),
              color(Style.Colors.white),
              Style.Typeface.ibmplexmono,
              fontSize(`rem(0.75)),
              borderRadius(`px(5)),
              // nudge so code background looks nicer
              marginRight(`rem(-0.25)),
              marginLeft(`rem(-0.25)),
            ],
          )
        )>
        {ReasonReact.string(src)}
      </pre>,
  };
};

let component = ReasonReact.statelessComponent("CryptoAppsSection");
let make = _ => {
  ...component,
  render: _self =>
    <div
      className=Css.(
        style([
          marginTop(`rem(4.75)),
          media(Style.MediaQuery.full, [marginTop(`rem(8.0))]),
        ])
      )>
      <h1 className=Style.H1.hero>
        {ReasonReact.string("Build global cryptocurrency apps with Coda")}
      </h1>
      <div>
        <p className=Style.Body.basic>
          {ReasonReact.string(
             "Empower your users with a direct secure connection to the Coda network.",
           )}
          <br />
          <br />
          {ReasonReact.string(
             "Coda will be able to be embedded into any webpage or app with just a script tag and a couple lines of JavaScript.",
           )}
        </p>
      </div>
      <a
        href=Links.mailingList
        className=Css.(
          merge([Style.Link.style, style([marginTop(`rem(1.5))])])
        )>
        {ReasonReact.string(
           {j|Stay updated about developing with Coda\u00A0→|j},
         )}
      </a>
      <Code
        src={|<script src="https://codaprotocol.com/api.js"></script>
<script>
  onClick(button)
     .then(() => Coda.requestWallet())
     .then((wallet) => Coda.sendTransaction(wallet, ...))
</script>|}
      />
    </div>,
};
