module Legend = {
  module Square = {
    [@react.component]
    let make = (~className, ~borderColor, ~fillColor, ~dims) => {
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
    };
  };

  module SmallRow = {
    [@react.component]
    let make = (~themeColor, ~copy) => {
      <div className=Css.(style([display(`flex), alignItems(`center)]))>
        <Square
          className=Css.(
            style([
              marginRight(`rem(0.5)),
              media(Theme.MediaQuery.notMobile, [marginRight(`rem(0.75))]),
            ])
          )
          borderColor=None
          fillColor=themeColor
          dims=(`rem(1.0), `rem(1.0))
        />
        <h3
          className=Css.(
            merge([
              Theme.H3.basic,
              style([
                fontWeight(`medium),
                marginTop(`zero),
                marginBottom(`zero),
                color(themeColor),
              ]),
            ])
          )>
          {React.string(copy)}
        </h3>
      </div>;
    };
  };

  [@react.component]
  let make = (~className) => {
    <div
      className=Css.(
        merge([
          className,
          style([
            justifyContent(`flexStart),
            alignItems(`center),
            media(Theme.MediaQuery.notMobile, [justifyContent(`center)]),
          ]),
        ])
      )>
      <div
        ariaHidden=true
        className=Css.(
          style([
            display(`flex),
            marginTop(`zero),
            marginBottom(`zero),
            marginRight(`rem(1.0)),
            media(Theme.MediaQuery.notMobile, [marginRight(`rem(2.25))]),
          ])
        )>
        <Square
          className=Css.(style([marginRight(`rem(0.75))]))
          borderColor={Some(Theme.Colors.clover)}
          fillColor=Theme.Colors.lightClover
          dims=(`rem(2.5), `rem(2.5))
        />
        <h5
          className=Css.(
            merge([
              Theme.H5.tight,
              style([
                width(`rem(8.0)),
                marginTop(`zero),
                marginBottom(`zero),
              ]),
            ])
          )>
          {React.string("Consensus Participants")}
        </h5>
      </div>
      <div ariaHidden=true>
        <SmallRow themeColor=Theme.Colors.teal copy="Individuals" />
        <SmallRow themeColor=Theme.Colors.navy copy="Organizations" />
      </div>
    </div>;
  };
};

module Figure = {
  [@react.component]
  let make = (~link, ~captionColor, ~dims, ~caption, ~alt) => {
    let (w, h) = dims;
    <figure
      className=Css.(
        style([
          marginTop(`rem(2.0)),
          display(`flex),
          flexDirection(`column),
          alignItems(`center),
          justifyContent(`center),
          width(`rem(19.5)),
          media(Theme.MediaQuery.notMobile, [width(`rem(20.625))]),
        ])
      )>
      <Svg
        className=Css.(
          style([
            // on mobile we want to square our figures with the height size
            width(`rem(h)),
            media(Theme.MediaQuery.notMobile, [width(`rem(w))]),
          ])
        )
        dims
        alt
        link
      />
      <figcaption
        className=Css.(
          merge([
            Theme.H3.basic,
            style([
              marginTop(`rem(1.5)),
              color(captionColor),
              fontWeight(`medium),
              textAlign(`center),
            ]),
          ])
        )>
        {React.string(caption)}
      </figcaption>
    </figure>;
  };
};

let legendQuery = "(min-width: 68.8125rem)";

[@react.component]
let make = () => {
  <div className=Css.(style([marginTop(`rem(2.5))]))>
    <Title fontColor=Theme.Colors.denimTwo text="Inclusive consensus" />
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
          media(Theme.MediaQuery.notMobile, [justifyContent(`spaceAround)]),
        ])
      )>
      <Figure
        link="/static/img/coda-figure.svg"
        dims=(15.125, 15.125)
        caption="Coda"
        alt="Figure showing everyone participating in consensus, including individual users of Coda."
        captionColor=Theme.Colors.clover
      />
      <Figure
        link="/static/img/other-blockchains-figure.svg"
        dims=(CryptoAppsSection.middleElementWidthRems, 13.75)
        caption="Other Blockchains"
        alt="Figure showing few participants in consensus, most of which are organizations, rather than individuals."
        captionColor=Theme.Colors.navy
      />
      <div>
        <div
          className=Css.(style([display(`flex), justifyContent(`center)]))>
          <SideText
            paragraphs=[|
              `styled([
                `emph(
                  "Simple, fair consensus designed so you can participate",
                ),
                `str(
                  ". Participation is proportional to how much stake you have in the protocol with no lockups, no forced delegation, and low bandwidth requirements.",
                ),
              ]),
              `str(
                "With just a small stake you'll be able to participate directly in consensus.",
              ),
            |]
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
  </div>;
};
