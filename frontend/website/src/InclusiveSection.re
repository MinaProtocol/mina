module Legend = {
  module Square = {
    let component =
      ReasonReact.statelessComponent("InclusiveSection.Legend.Square");
    let make = (~className, ~borderColor, ~fillColor, ~dims, _children) => {
      ...component,
      render: _self => {
        let borderRule =
          switch (borderColor) {
          | None => []
          | Some(color) => [Css.border(`px(3), `solid, color)]
          };

        <div
          className=Css.(
            merge([
              className,
              style([
                width(fst(dims)),
                height(snd(dims)),
                backgroundColor(fillColor),
                ...borderRule,
              ]),
            ])
          )
        />;
      },
    };
  };

  module SmallRow = {
    let component =
      ReasonReact.statelessComponent("InclusiveSection.Legend.SmallRow");
    let make = (~themeColor, ~copy, _children) => {
      ...component,
      render: _self => {
        <div className=Css.(style([display(`flex), alignItems(`center)]))>
          <Square
            className=Css.(
              style([
                marginRight(`rem(0.5)),
                media(
                  Style.MediaQuery.notMobile,
                  [marginRight(`rem(0.75))],
                ),
              ])
            )
            borderColor=None
            fillColor=themeColor
            dims=(`rem(1.0), `rem(1.0))
          />
          <h3
            className=Css.(
              merge([
                Style.H3.basic,
                style([
                  fontWeight(`medium),
                  marginTop(`zero),
                  marginBottom(`zero),
                  color(themeColor),
                ]),
              ])
            )>
            {ReasonReact.string(copy)}
          </h3>
        </div>;
      },
    };
  };

  let component = ReasonReact.statelessComponent("InclusiveSection.Legend");
  let make = (~className, _children) => {
    ...component,
    render: _self => {
      <div
        className=Css.(
          merge([
            className,
            style([
              justifyContent(`flexStart),
              alignItems(`center),
              media(Style.MediaQuery.notMobile, [justifyContent(`center)]),
            ]),
          ])
        )>
        <div
          className=Css.(
            style([
              display(`flex),
              marginTop(`zero),
              marginBottom(`zero),
              marginRight(`rem(0.25)),
              media(Style.MediaQuery.notMobile, [marginRight(`rem(2.25))]),
            ])
          )>
          <Square
            className=Css.(style([marginRight(`rem(0.75))]))
            borderColor={Some(Style.Colors.clover)}
            fillColor=Style.Colors.lightClover
            dims=(`rem(2.25), `rem(2.25))
          />
          <h5
            className=Css.(
              merge([
                Style.H5.tight,
                style([
                  width(`rem(8.0)),
                  marginTop(`zero),
                  marginBottom(`zero),
                ]),
              ])
            )>
            {ReasonReact.string("Consensus Participants")}
          </h5>
        </div>
        <div>
          <SmallRow themeColor=Style.Colors.teal copy="Individuals" />
          <SmallRow themeColor=Style.Colors.navy copy="Organizations" />
        </div>
      </div>;
    },
  };
};

module Figure = {
  let component = ReasonReact.statelessComponent("InclusiveSection.Figure");
  let make = (~captionColor, ~link, ~dims, ~caption, _children) => {
    ...component,
    render: _self => {
      <figure
        className=Css.(
          style([
            unsafe("margin-block-start", "0"),
            unsafe("margin-block-end", "0"),
            unsafe("margin-inline-start", "0"),
            unsafe("margin-inline-end", "0"),
            marginTop(`rem(2.0)),
            display(`flex),
            flexDirection(`column),
            alignItems(`center),
            justifyContent(`center),
            width(`rem(20.625)),
          ])
        )>
        <Svg dims link />
        <figcaption
          className=Css.(
            merge([
              Style.H3.basic,
              style([
                marginTop(`rem(1.5)),
                color(captionColor),
                fontWeight(`medium),
                textAlign(`center),
              ]),
            ])
          )>
          {ReasonReact.string(caption)}
        </figcaption>
      </figure>;
    },
  };
};

let legendQuery = "(min-width: 66.8125rem)";

let component = ReasonReact.statelessComponent("InclusiveSection");
let make = _ => {
  ...component,
  render: _self =>
    <div className=Css.(style([marginTop(`rem(2.5))]))>
      <Title fontColor=Style.Colors.denimTwo text="Inclusive consensus" />
      <Legend
        className=Css.(
          style([display(`none), media(legendQuery, [display(`flex)])])
        )
      />
      <div
        className=Css.(
          style([
            display(`flex),
            justifyContent(`spaceBetween),
            alignItems(`center),
            flexWrap(`wrapReverse),
            media(
              Style.MediaQuery.notMobile,
              [justifyContent(`spaceAround)],
            ),
          ])
        )>
        <Figure
          link="/static/img/coda-figure.svg"
          dims=(15.125, 15.125)
          caption="Coda"
          captionColor=Style.Colors.clover
        />
        <Figure
          link="/static/img/other-blockchains-figure.svg"
          dims=(CryptoAppsSection.middleElementWidthRems, 13.75)
          caption="Other Blockchains"
          captionColor=Style.Colors.navy
        />
        <div>
          <div
            className=Css.(style([display(`flex), justifyContent(`center)]))>
            <SideText
              paragraphs=[|
                "Simple, fair consensus. Participation is proportional to how much stake you have in the protocol with no lockups, no forced delegation, and low bandwidth requirements.",
                "With just a small stake, you'll be able to participate directly in consensus and earn Coda.",
              |]
              cta="Stay updated about participating in consensus"
            />
          </div>
          <Legend
            className=Css.(
              style([
                display(`flex),
                marginTop(`rem(2.0)),
                media(legendQuery, [display(`none)]),
              ])
            )
          />
        </div>
      </div>
    </div>,
};
