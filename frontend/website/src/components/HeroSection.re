module Copy = {
  [@react.component]
  let make = () => {
    <div
      className=Css.(
        style([
          display(`flex),
          flexDirection(`column),
          justifyContent(`center),
          width(`percent(100.0)),
          maxWidth(`rem(37.0)),
          minWidth(`rem(17.5)),
          media("(min-width: 30rem)", [minWidth(`rem(24.0))]),
          media(
            Theme.MediaQuery.full,
            [width(`percent(60.0)), minWidth(`rem(24.0))],
          ),
          media(Theme.MediaQuery.somewhatLarge, [minWidth(`rem(32.))]),
        ])
      )>
      <div
        className=Css.(
          style([media(Theme.MediaQuery.full, [minWidth(`rem(25.5))])])
        )>
        <h1
          className=Css.(
            merge([
              Theme.H1.hero,
              style([
                color(Theme.Colors.denimTwo),
                marginTop(`zero),
                marginBottom(`zero),
                media(Theme.MediaQuery.full, [marginTop(`rem(1.5))]),
              ]),
            ])
          )>
          {React.string(
             {j|A cryptocurrency with a tiny portable blockchain.|j},
           )}
        </h1>
        <p
          className=Css.(
            merge([
              Theme.Body.big,
              style([
                marginTop(`rem(2.0)),
                maxWidth(`rem(30.0)),
                // align with the grid
                media(
                  Theme.MediaQuery.full,
                  [marginTop(`rem(1.75)), marginBottom(`rem(2.0))],
                ),
              ]),
            ])
          )>
          <span>
            {React.string(
               "Coda swaps the traditional blockchain for a tiny cryptographic proof, enabling a cryptocurrency as accessible as any other app or website. This makes it ",
             )}
          </span>
          <span className=Theme.Body.big_semibold>
            {React.string(
               "dramatically easier to develop user friendly crypto apps",
             )}
          </span>
          <span>
            {React.string(
               {j| that run natively in the browser, and enables more inclusive, sustainable\u00A0consensus.|j},
             )}
          </span>
          <br />
        </p>
      </div>
      <GenesisCTA />
    </div>;
  };
};

module Graphic = {
  module Big = {
    let svg =
      <Svg
        className=Css.(style([marginTop(`rem(-0.625))]))
        link="/static/img/hero-illustration.svg"
        dims=(9.5625, 33.375)
        alt="Huge tower of blocks representing the data required by other blockchains."
      />;
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
            ]),
          ])
        )>
        children
        <div>
          <h3
            className=Css.(
              merge([
                Theme.H3.basic,
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
                Theme.H3.basic,
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
              Theme.H5.basic,
              style([marginTop(`rem(1.125)), marginBottom(`rem(0.375))]),
            ])
          )>
          {React.string(label)}
        </h5>
      </div>;
    };
  };

  [@react.component]
  let make = () => {
    Css.(
      <div
        className={style([
          width(`percent(100.0)),
          maxWidth(`rem(20.0)),
          marginRight(`rem(2.0)),
          media(Theme.MediaQuery.veryVeryLarge, [marginRight(`rem(4.75))]),
        ])}>
        <div
          className={style([
            display(`flex),
            justifyContent(`spaceAround),
            width(`percent(100.0)),
            media(Theme.MediaQuery.full, [justifyContent(`spaceBetween)]),
          ])}>
          <Info
            sizeEmphasis=false
            name="Coda"
            size="22kB"
            label="Fixed"
            textColor=Theme.Colors.bluishGreen>
            <img
              className={style([width(`rem(0.625))])}
              src="/static/img/coda-icon.png"
              alt="Small Coda logo representing its small, fixed blockchain size."
            />
          </Info>
          <Info
            className={style([
              marginRight(`rem(-1.5)),
              media(Theme.MediaQuery.full, [marginRight(`zero)]),
            ])}
            sizeEmphasis=true
            name="Other blockchains"
            size="2TB+"
            label="Increasing"
            textColor=Theme.Colors.rosebud>
            Big.svg
          </Info>
        </div>
      </div>
    );
  };
};

[@react.component]
let make = () => {
  <div
    className=Css.(
      style([
        display(`flex),
        justifyContent(`spaceAround),
        flexWrap(`wrap),
        maxWidth(`rem(73.0)),
        media(
          Theme.MediaQuery.full,
          [flexWrap(`nowrap), justifyContent(`spaceBetween)],
        ),
        media(
          Theme.MediaQuery.somewhatLarge,
          [marginLeft(`px(80)), marginRight(`px(80))],
        ),
      ])
    )>
    <Copy />
    <Graphic />
  </div>;
};
