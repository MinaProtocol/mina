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
              Style.Typeface.ibmplexsans,
              fontSize(`rem(0.8125)),
              borderRadius(`px(12)),
              lineHeight(`rem(1.25)),
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

let swapQuery = "(min-width: 70rem)";

module ImageCollage = {
  let component =
    ReasonReact.statelessComponent("CryptoAppsSection.ImageCollage");
  let make = (~className, _children) => {
    ...component,
    render: _self =>
      <div
        className=Css.(
          merge([
            className,
            style([
              position(`relative),
              top(`zero),
              left(`zero),
              media(swapQuery, [position(`static)]),
            ]),
          ])
        )>
        <Image
          className=Css.(
            style([
              position(`relative),
              top(`zero),
              left(`zero),
              right(`zero),
              bottom(`zero),
              margin(`auto),
              maxWidth(`percent(100.0)),
            ])
          )
          name="/static/img/map"
        />
        <Image
          className=Css.(
            style([
              position(`absolute),
              top(`zero),
              left(`zero),
              right(`zero),
              bottom(`zero),
              margin(`auto),
              maxWidth(`percent(100.0)),
            ])
          )
          name="/static/img/build-illustration"
        />
        <Image
          className=Css.(
            style([
              position(`absolute),
              top(`zero),
              left(`zero),
              right(`zero),
              bottom(`zero),
              margin(`auto),
              maxWidth(`percent(100.0)),
            ])
          )
          name="/static/img/coda"
        />
      </div>,
  };
};

let component = ReasonReact.statelessComponent("CryptoAppsSection");
let make = _ => {
  ...component,
  render: _self => {
    <div
      className=Css.(
        style([
          marginTop(`rem(4.75)),
          media(Style.MediaQuery.full, [marginTop(`rem(8.0))]),
        ])
      )>
      <Title
        fontColor=Style.Colors.denimTwo
        text="Build global cryptocurrency apps with Coda"
      />
      <div
        className=Css.(
          style([position(`relative), top(`zero), left(`zero)])
        )>
        <ImageCollage
          className=Css.(
            style([display(`none), media(swapQuery, [display(`block)])])
          )
        />
        <div
          className=Css.(
            style([
              display(`flex),
              flexWrap(`wrapReverse),
              justifyContent(`spaceBetween),
              alignItems(`center),
              marginLeft(`auto),
              marginRight(`auto),
              marginBottom(`rem(4.0)),
              maxWidth(`rem(78.0)),
              // vertically/horiz center absolutely
              media(
                swapQuery,
                [
                  position(`absolute),
                  top(`percent(50.0)),
                  left(`percent(50.0)),
                  transforms([
                    `translateX(`percent(-50.0)),
                    `translateY(`percent(-50.0)),
                  ]),
                  width(`percent(100.0)),
                ],
              ),
            ])
          )>
          <Code
            src={|<script src="https://codaprotocol.com/api.js"></script>
<script>
  onClick(button)
     .then(() => Coda.requestWallet())
     .then((wallet) => Coda.sendTransaction(wallet, ...))
</script>|}
          />
          <SideText
            paragraphs=[|
              "Empower your users with a direct secure connection to the Coda network.",
              "Coda will be able to be embedded into any webpage or app with just a script tag and a couple lines of JavaScript.",
            |]
            cta="Stay updated about developing with Coda"
          />
        </div>
        <ImageCollage
          className=Css.(
            style([
              display(`block),
              marginBottom(`rem(4.0)),
              media(swapQuery, [display(`none)]),
            ])
          )
        />
      </div>
    </div>;
  },
};
