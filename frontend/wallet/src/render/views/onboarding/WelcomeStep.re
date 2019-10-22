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
  let fadeIn =
    keyframes([
      (0, [opacity(0.), top(`px(50))]),
      (100, [opacity(1.), top(`px(0))]),
    ]);

  let heroLeft = {
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`center),
      width(`percent(100.0)),
      maxWidth(`rem(32.0)),
      marginLeft(`px(80)),
      marginTop(`px(80)),
      marginRight(`px(80)),
    ]);
  };
  let header = {
    merge([
      Theme.Text.Header.h1,
      style([
        fontSize(`rem(2.70)),
        animation(fadeIn, ~duration=1000, ~iterationCount=`count(1)),
      ]),
    ]);
  };
  let heroBody = {
    merge([
      Theme.Text.Body.regularLight,
      style([
        opacity(0.),
        marginTop(`rem(2.)),
        marginBottom(`rem(3.)),
        maxWidth(`rem(28.)),
        color(Theme.Colors.midnightBlue),
        animation(fadeIn, ~duration=1050, ~iterationCount=`count(1)),
        animationDelay(250),
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
    <div className=Styles.map>
      <img src="map@2x.png" alt="Map" className=Styles.map />
    </div>
    <div className=Styles.hero>
      <div className=Styles.heroLeft>
        <h1 className=Styles.header>
          {React.string("Welcome to Coda Wallet!")}
        </h1>
        <p className=Styles.heroBody>
          {React.string(
             {|Coda swaps the traditional blockchain for a tiny cryptographic proof, enabling a cryptocurrency that stays the same size forever. With the Coda Wallet you can send, recieve and view transactions on the Coda network.|},
           )}
        </p>
        <div> <Button label="Continue" onClick={_ => nextStep()} /> </div>
      </div>
      <div />
      <div className=Styles.image>
        <Info
          sizeEmphasis=false
          name="Coda"
          size="22kB"
          label="Fixed"
          textColor=Theme.Colors.jungle>
          <img
            className=Styles.codaImage
            src="coda-icon.png"
            alt="Small Coda logo representing its small, fixed blockchain size."
          />
        </Info>
        <Info
          className=Styles.towerImage
          sizeEmphasis=true
          name="Other blockchains"
          size="2TB+"
          label="Increasing"
          textColor=Theme.Colors.roseBud>
          <img
            src="hero-illustration.png"
            alt="Huge tower of blocks representing the data required by other blockchains."
          />
        </Info>
      </div>
    </div>
  </div>;
};
