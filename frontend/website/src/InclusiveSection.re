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
            className=Css.(style([marginRight(`rem(0.75))]))
            borderColor=None
            fillColor=themeColor
            dims=(`rem(1.0), `rem(1.0))
          />
          <h3
            className=Css.(
              merge([
                Style.H3.basic,
                style([
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
  let make = _ => {
    ...component,
    render: _self => {
      <div
        className=Css.(
          style([
            display(`flex),
            justifyContent(`center),
            alignItems(`center),
          ])
        )>
        <div
          className=Css.(
            style([
              display(`flex),
              marginTop(`zero),
              marginBottom(`zero),
              marginRight(`rem(2.25)),
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
                Style.H5.basic,
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
      <figure>
        <Svg dims link />
        <figcaption
          className=Css.(
            merge([
              Style.H3.basic,
              style([
                marginTop(`rem(1.5)),
                color(captionColor),
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

let component = ReasonReact.statelessComponent("InclusiveSection");
let make = _ => {
  ...component,
  render: _self =>
    <div className=Css.(style([marginTop(`rem(2.5))]))>
      <Title fontColor=Style.Colors.denimTwo text="Inclusive consensus" />
      <Legend />
      <div
        className=Css.(
          style([
            display(`flex),
            justifyContent(`spaceAround),
            alignItems(`center),
            flexWrap(`wrapReverse),
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
        <SideText
          paragraphs=[|
            "Simple, fair consensus. Participation is proportional to how much stake you have in the protocol with no lockups, no forced delegation, and low bandwidth requirements.",
            "With just a small stake, you'll be able to participate directly in consensus and earn Coda.",
          |]
          cta="Stay updated about participating in consensus"
        />
      </div>
    </div>,
};
