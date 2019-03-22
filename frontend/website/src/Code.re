let extraHeaders = <> Head.legacyStylesheets </>;

let border =
  Css.(
    style([
      borderTop(`rem(0.1), `solid, Style.Colors.veryLightGrey),
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
      <a href=link className="no-underline pointer">
        <div>
          <div className="dn db-ns">
            <div className="flex items-center justify-between mt4 mb4">
              <h2 className="w310px ibmplex f2 fw3 ocean mt0 mb4 mb0-ns">
                {ReasonReact.string(name)}
              </h2>
              <div className="w-60">
                <span className="mt2 mw55 ibmplex lightsilver fw4 lh-copy">
                  {ReasonReact.string(description)}
                </span>
              </div>
              <div className="ocean o-40 mr3 ml4-ns">
                <i className="f1 fas fa-chevron-right" />
              </div>
            </div>
          </div>
          <div className="db dn-ns">
            <div>
              <div className="flex justify-between mt4">
                <h2 className="w310px ibmplex f2 fw3 ocean mt0 mb4 mb0-ns">
                  {ReasonReact.string(name)}
                </h2>
                <div className="ocean o-40 mr3 ml4-ns">
                  <i className="f1 fas fa-chevron-right" />
                </div>
              </div>
              <div className="mb4">
                <span className="mt2 mw55 ibmplex lightsilver fw4 lh-copy">
                  {ReasonReact.string(description)}
                </span>
              </div>
            </div>
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
      <div
        className=Css.(
          style([
            display(`flex),
            flexWrap(`wrap),
            justifyContent(`spaceAround),
            alignItems(`center),
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
                // minWidth(`rem(15.)),
                marginTop(`rem(2.)),
              ]),
            ])
          )>
          {ReasonReact.string(
             "Coda is a cryptocurrency that can scale to millions of users and thousands of transactions per second while remaining decentralized. Any client, including smartphones, will be able to instantly validate the state of the ledger.",
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
                hover([color(Style.Colors.hyperlink)]),
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
                justifyContent(`center),
                backgroundColor(Style.Colors.tealAlpha(0.08)),
                hover([backgroundColor(Style.Colors.tealAlpha(0.05))]),
                borderRadius(`px(10)),
                height(`rem(6.25)),
              ])
            )>
            <div className=Css.(style([marginRight(`rem(0.5))]))>
              {ReasonReact.string("Clone on GitHub")}
            </div>
            <i className="f1 fas fa-chevron-right" />
          </div>
        </a>
        <Item
          name="Get Started"
          link="https://github.com/CodaProtocol/coda/blob/master/docs/demo.md"
          description="Spin up a local testnet, send payments, and learn how to interact with the Coda client"
        />
        <hr className=border />
        <Item
          name="Contribute"
          link="https://github.com/CodaProtocol/coda/blob/master/CONTRIBUTING.md"
          description="Join our open source community, work on issues, and learn how we use novel cryptography to create a scalable cryptocurrency network."
        />
        <hr className=border />
        <Item
          name="Learn More"
          link="https://github.com/CodaProtocol/coda/blob/master/docs/lifecycle_of_a_payment_lite.md"
          description="Dive into the cutting-edge research and engineering that underlies Coda's technology"
        />
      </div>
    </div>;
  },
};
