module Styles = {
  open Css;

  let map =
    style([
      position(`fixed),
      left(`px(0)),
      top(`px(0)),
      zIndex(-1),
      maxWidth(`percent(100.)),
    ]);

  let hero = {
    style([display(`flex), flexDirection(`row)]);
  };

  let heroLeft = {
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`center),
      width(`percent(100.0)),
      maxWidth(`rem(32.0)),
      marginLeft(`rem(5.)),
      marginRight(`rem(5.)),
    ]);
  };
  let header = {
    merge([
      Theme.Text.Header.h1,
      style([color(white), fontSize(`rem(2.70))]),
    ]);
  };
  let heroBody = {
    merge([
      Theme.Text.Body.regularLight,
      style([
        marginTop(`rem(1.)),
        marginBottom(`rem(3.)),
        maxWidth(`rem(28.)),
        color(white),
        animationFillMode(`forwards),
      ]),
    ]);
  };

  let image = {
    style([
      width(`percent(100.0)),
      maxWidth(`rem(15.0)),
      marginRight(`rem(2.0)),
      display(`flex),
      justifyContent(`spaceAround),
    ]);
  };

  let codaImage = {
    style([width(`rem(0.625))]);
  };

  let towerImage = {
    style([marginRight(`rem(-1.5))]);
  };
};

module Info = {
  [@react.component]
  let make =
      (
        ~className="",
        ~sizeEmphasis,
        ~name,
        ~size,
        ~label,
        ~textColor,
        ~children,
      ) => {
    <div
      className=Css.(
        merge([
          className,
          style([
            display(`flex),
            flexDirection(`column),
            justifyContent(`flexEnd),
            alignItems(`center),
            textAlign(`center),
          ]),
        ])
      )>
      children
      <div>
        <h3
          className=Css.(
            merge([
              Theme.Text.Header.h3,
              style([
                color(textColor),
                fontWeight(`medium),
                marginTop(`rem(1.25)),
                marginBottom(`zero),
              ]),
            ])
          )>
          {React.string(name)}
        </h3>
        <h3
          className=Css.(
            merge([
              Theme.Text.Header.h3,
              style([
                color(textColor),
                marginTop(`zero),
                marginBottom(`zero),
                fontWeight(sizeEmphasis ? `bold : `normal),
              ]),
            ])
          )>
          {React.string(size)}
        </h3>
      </div>
      <h5
        className=Css.(
          merge([
            Theme.Text.Header.h5,
            style([marginTop(`rem(1.125)), marginBottom(`rem(0.375))]),
          ])
        )>
        {React.string(label)}
      </h5>
    </div>;
  };
};

[@react.component]
let make = (~nextStep) => {
  <div className=Theme.Onboarding.main>
    <div className=Styles.hero>
      <div className=Styles.heroLeft>
        <FadeIn duration=500 delay=0>
          <h1 className=Styles.header> {React.string("Welcome")} </h1>
        </FadeIn>
        <FadeIn duration=500 delay=150>
          <p className=Styles.heroBody>
            {React.string(
               {|You're about to install everything you need to participate in Coda Protocol's revolutionary blockchain, which will make cryptocurrency accessible to everyone.|},
             )}
          </p>
        </FadeIn>
        <div>
          <Button
            label="Get Started"
            style=Button.HyperlinkBlue
            onClick={_ => nextStep()}
          />
        </div>
      </div>
      <div />
    </div>
  </div>;
};
