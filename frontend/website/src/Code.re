let chevronColor = c =>
  Css.unsafe("--chevron-color", Style.Colors.string(c));

let chevron = defaultColor =>
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="27"
    height="44"
    viewBox="0 0 27 44">
    <path
      fill={Style.Colors.string(defaultColor)}
      style={ReactDOMRe.Style.unsafeAddProp(
        ReactDOMRe.Style.make(),
        "fill",
        "var(--chevron-color)",
      )}
      fillRule="nonzero"
      d="M26.312 21.821l-1.806 1.85L4.962 43.642 0 39.942l17.737-18.121L0 3.7 4.962 0l19.544 19.971 1.806 1.85z"
    />
  </svg>;

let border =
  Css.(
    style([
      borderTop(`px(2), `solid, Style.Colors.veryLightGrey),
      borderBottomWidth(`zero),
      borderLeftWidth(`zero),
      borderRightWidth(`zero),
      width(`percent(100.)),
    ])
  );

module Item = {
  let component = ReasonReact.statelessComponent("Code.Item");
  let make = (~name, ~link, ~description, _children) => {
    ...component,
    render: _self =>
      <a
        href=link
        className=Css.(
          style([
            textDecoration(`none),
            color(Style.Colors.teal),
            cursor(`pointer),
            width(`percent(100.)),
            marginRight(`rem(2.)),
            chevronColor(Style.Colors.tealAlpha(0.1)),
            hover([
              color(Style.Colors.hyperlink),
              chevronColor(Style.Colors.hyperlinkAlpha(0.5)),
            ]),
          ])
        )>
        <div
          className=Css.(
            merge([
              Style.H2.basic,
              style([
                display(`flex),
                justifyContent(`spaceBetween),
                alignItems(`center),
                margin(`rem(0.0)),
                flexWrap(`wrap),
                height(`auto),
                media(
                  Style.MediaQuery.notMobile,
                  [flexWrap(`nowrap), height(`rem(7.5))],
                ),
              ]),
            ])
          )>
          <h2
            className=Css.(
              merge([
                Style.H2.basic,
                style([
                  width(`rem(12.)),
                  minWidth(`rem(10.)),
                  marginRight(`rem(0.5)),
                  marginTop(`rem(0.5)),
                  marginBottom(`rem(0.5)),
                  order(1),
                  unsafe("margin-block-start", "0"),
                  unsafe("margin-block-end", "0"),
                  unsafe("-webkit-margin-before", "0"),
                  unsafe("-webkit-margin-after", "0"),
                ]),
              ])
            )>
            {ReasonReact.string(name)}
          </h2>
          <div
            className=Css.(
              merge([
                Style.Body.basic,
                style([
                  maxWidth(`rem(25.)),
                  display(`flex),
                  margin(`rem(0.0)),
                  order(5),
                  media(Style.MediaQuery.notMobile, [order(2)]),
                ]),
              ])
            )>
            {ReasonReact.string(description)}
          </div>
          <div
            className=Css.(
              style([
                order(3),
                marginTop(`rem(0.5)),
                marginLeft(`rem(0.5)),
                marginRight(`rem(2.0)),
              ])
            )>
            {chevron(Style.Colors.tealAlpha(0.1))}
          </div>
        </div>
      </a>,
  };
};

let component = ReasonReact.statelessComponent("CodePage");
let make = _ => {
  ...component,
  render: _self => {
    <div
      className=Css.(
        style([
          maxWidth(`rem(50.)),
          marginLeft(`auto),
          marginRight(`auto),
        ])
      )>
      <h3 className=Style.H3.wings> {ReasonReact.string("Run Coda")} </h3>
      <code
        className=Css.(
          style([
            marginTop(`rem(2.5)),
            Style.Typeface.ibmplexmono,
            fontWeight(`num(600)),
            display(`flex),
            flexDirection(`column),
            justifyContent(`spaceBetween),
            alignItems(`flexStart),
            backgroundColor(Style.Colors.navy),
            color(Style.Colors.white),
            height(`rem(9.375)),
            borderRadius(`px(9)),
            padding(`rem(1.5)),
          ])
        )>
        <div>
          {ReasonReact.string(
             "$ docker run -d --name coda codaprotocol/coda:demo",
           )}
        </div>
        <div> {ReasonReact.string("$ docker exec -it coda /bin/bash")} </div>
        <div> {ReasonReact.string("$ watch coda client status")} </div>
      </code>
      <div>
        <div
          className=Css.(
            style([
              display(`flex),
              flexWrap(`wrap),
              justifyContent(`spaceBetween),
              alignItems(`center),
              marginTop(`rem(0.5)),
              marginBottom(`rem(1.0)),
            ])
          )>
          <p
            className=Css.(
              merge([
                Style.Body.basic,
                style([
                  color(Style.Colors.slate),
                  maxWidth(`rem(26.875)),
                  flexShrink(1),
                  flexGrow(1.0),
                  marginRight(`rem(0.5)),
                  width(`rem(15.)),
                  marginTop(`rem(2.)),
                  marginRight(`rem(1.0)),
                ]),
              ])
            )>
            {ReasonReact.string(
               "Coda is a cryptocurrency that can scale to millions of users and thousands of \
             transactions per second while remaining decentralized. Any client, including \
             smartphones, will be able to instantly validate the state of the ledger.",
             )}
          </p>
          <a
            href="https://github.com/CodaProtocol/coda"
            className=Css.(
              merge([
                Style.Link.init,
                style([
                  Style.Typeface.aktivgrotesk,
                  letterSpacing(`rem(0.1875)),
                  textTransform(`uppercase),
                  color(Style.Colors.fadedBlue),
                  marginTop(`rem(1.)),
                  chevronColor(Style.Colors.tealAlpha(0.1)),
                  hover([
                    color(Style.Colors.hyperlink),
                    chevronColor(Style.Colors.hyperlinkAlpha(0.5)),
                  ]),
                ]),
              ])
            )>
            <div
              className=Css.(
                style([
                  display(`flex),
                  alignItems(`center),
                  whiteSpace(`nowrap),
                  Style.Typeface.aktivgrotesk,
                  padding(`rem(1.5)),
                  justifyContent(`spaceBetween),
                  backgroundColor(Style.Colors.tealAlpha(0.08)),
                  hover([backgroundColor(Style.Colors.tealAlpha(0.05))]),
                  borderRadius(`px(10)),
                  height(`rem(6.25)),
                ])
              )>
              <div className=Css.(style([marginRight(`rem(0.5))]))>
                {ReasonReact.string("Clone on GitHub")}
              </div>
              <div
                className=Css.(
                  style([
                    marginLeft(`rem(0.5)),
                    marginRight(`rem(0.5)),
                    marginTop(`rem(0.5)),
                  ])
                )>
                {chevron(Style.Colors.tealAlpha(0.1))}
              </div>
            </div>
          </a>
        </div>
        <Item
          name="Get Started"
          link="https://github.com/CodaProtocol/coda/blob/master/docs/demo.md"
          description="Spin up a local testnet, send payments, and learn how to interact with the Coda client"
        />
        <hr className=border ariaHidden=true />
        <Item
          name="Contribute"
          link="https://github.com/CodaProtocol/coda/blob/master/CONTRIBUTING.md"
          description="Join our open source community, work on issues, and learn \
          how we use novel cryptography to create a scalable cryptocurrency network."
        />
        <hr className=border ariaHidden=true />
        <Item
          name="Learn More"
          link="https://github.com/CodaProtocol/coda/blob/master/docs/lifecycle_of_a_payment_lite.md"
          description="Dive into the cutting-edge research and engineering that underlies Coda's technology"
        />
      </div>
    </div>;
  },
};
