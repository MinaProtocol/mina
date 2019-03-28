module Copy = {
  let component = ReasonReact.statelessComponent("HeroSection.Copy");
  let make = _ => {
    ...component,
    render: _self =>
      <div
        className=Css.(
          style([
            display(`flex),
            flexDirection(`column),
            justifyContent(`center),
            width(`percent(100.0)),
            maxWidth(`rem(37.0)),
            minWidth(`rem(17.5)),
            media(
              Style.MediaQuery.full,
              [width(`percent(50.0)), minWidth(`rem(24.0))],
            ),
            media("(min-width: 30rem)", [minWidth(`rem(24.0))]),
          ])
        )>
        <div
          className=Css.(
            style([media(Style.MediaQuery.full, [minWidth(`rem(25.5))])])
          )>
          <h1
            className=Css.(
              merge([
                Style.H1.hero,
                style([
                  color(Style.Colors.denimTwo),
                  marginTop(`zero),
                  marginBottom(`zero),
                  media(Style.MediaQuery.full, [marginTop(`rem(1.5))]),
                ]),
              ])
            )>
            {ReasonReact.string(
               "A cryptocurrency with a tiny, portable blockchain.",
             )}
          </h1>
          <p
            className=Css.(
              merge([
                Style.Body.big,
                style([
                  marginTop(`rem(2.0)),
                  maxWidth(`rem(28.0)),
                  // align with the grid
                  media(
                    Style.MediaQuery.full,
                    [marginTop(`rem(1.75)), marginBottom(`rem(11.875))],
                  ),
                ]),
              ])
            )>
            <span>
              {ReasonReact.string(
                 "Coda is the first cryptocurrency with a succinct blockchain. Our lightweight blockchain means ",
               )}
            </span>
            <span className=Style.Body.big_semibold>
              {ReasonReact.string("anyone can use Coda directly")}
            </span>
            <span>
              {ReasonReact.string(
                 " from any device, in less data than a few tweets.",
               )}
            </span>
          </p>
        </div>
      </div>,
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
    let component =
      ReasonReact.statelessComponent("HeroSection.Graphic.Info");

    let make =
        (
          ~className="",
          ~sizeEmphasis,
          ~name,
          ~size,
          ~label,
          ~textColor,
          children,
        ) => {
      ...component,
      render: _ =>
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
          {children[0]}
          <div>
            <h3
              className=Css.(
                merge([
                  Style.H3.basic,
                  style([
                    color(textColor),
                    fontWeight(`medium),
                    marginTop(`rem(1.25)),
                    marginBottom(`zero),
                  ]),
                ])
              )>
              {ReasonReact.string(name)}
            </h3>
            <h3
              className=Css.(
                merge([
                  Style.H3.basic,
                  style([
                    color(textColor),
                    marginTop(`zero),
                    marginBottom(`zero),
                    fontWeight(sizeEmphasis ? `bold : `normal),
                  ]),
                ])
              )>
              {ReasonReact.string(size)}
            </h3>
          </div>
          <h5
            className=Css.(
              merge([
                Style.H5.basic,
                style([
                  marginTop(`rem(1.125)),
                  marginBottom(`rem(0.375)),
                ]),
              ])
            )>
            {ReasonReact.string(label)}
          </h5>
        </div>,
    };
  };

  let component = ReasonReact.statelessComponent("HeroSection.Graphic");
  let make = _ => {
    ...component,
    render: _self =>
      Css.(
        <div
          className={style([
            width(`percent(100.0)),
            media(Style.MediaQuery.full, [maxWidth(`rem(22.625))]),
          ])}>
          <div
            className={style([
              display(`flex),
              justifyContent(`spaceAround),
              width(`percent(100.0)),
              media(Style.MediaQuery.full, [justifyContent(`spaceBetween)]),
            ])}>
            <Info
              sizeEmphasis=false
              name="Coda"
              size="22kB"
              label="Fixed"
              textColor=Style.Colors.bluishGreen>
              <Image
                className={style([width(`rem(0.625))])}
                name="/static/img/coda-icon"
                alt="Small Coda logo representing its small, fixed blockchain size."
              />
            </Info>
            <Info
              className={style([
                marginRight(`rem(-1.5)),
                media(Style.MediaQuery.full, [marginRight(`zero)]),
              ])}
              sizeEmphasis=true
              name="Other blockchains"
              size="2TB+"
              label="Increasing"
              textColor=Style.Colors.rosebud>
              Big.svg
            </Info>
          </div>
        </div>
      ),
  };
};

let component = ReasonReact.statelessComponent("HeroSection");
let make = _ => {
  ...component,
  render: _self =>
    <div
      className=Css.(
        style([
          display(`flex),
          justifyContent(`spaceAround),
          flexWrap(`wrap),
          media(Style.MediaQuery.full, [flexWrap(`nowrap)]),
        ])
      )>
      <Copy />
      <Graphic />
    </div>,
};
();
