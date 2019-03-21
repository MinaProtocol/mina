module Copy = {
  let component = ReasonReact.statelessComponent("HeroSection.Copy");
  let make = _ => {
    ...component,
    render: _self =>
      <div
        className=Css.(
          style([
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
        <h1
          className=Css.(
            merge([
              Style.H1.hero,
              style([
                marginTop(`rem(1.0)),
                media(Style.MediaQuery.full, [marginTop(`rem(1.5))]),
              ]),
            ])
          )>
          {ReasonReact.string(
             "A cryptocurrency with a tiny, portable blockchain.",
           )}
        </h1>
        <p className=Style.Body.big>
          <span>
            {ReasonReact.string(
               "Coda is the first cryptocurrency with a succinct blockchain. Out lightweight blockchain means ",
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
      </div>,
  };
};

module Graphic = {
  module Big = {
    let svg =
      <Svg link="/static/img/hero-illustration.svg" dims=(13.9375, 33.375) />;
  };

  module Small = {
    let svg = <Svg link="/static/img/icon.svg" dims=(0.625, 0.625) />;
  };

  module Info = {
    let component =
      ReasonReact.statelessComponent("HeroSection.Graphic.Info");

    let make = (~sizeEmphasis, ~name, ~size, ~label, ~textColor, children) => {
      ...component,
      render: _ =>
        <div
          className=Css.(
            style([
              display(`flex),
              flexDirection(`column),
              justifyContent(`flexEnd),
              alignItems(`center),
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
                    marginBottom(`px(0)),
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
                    marginTop(`px(0)),
                    marginBottom(`px(0)),
                    fontWeight(sizeEmphasis ? `bold : `normal),
                  ]),
                ])
              )>
              {ReasonReact.string(size)}
            </h3>
          </div>
          <h4
            className=Css.(
              merge([
                Style.H4.basic,
                style([marginTop(`rem(1.5)), marginBottom(`px(0))]),
              ])
            )>
            {ReasonReact.string(label)}
          </h4>
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
              Small.svg
            </Info>
            <Info
              sizeEmphasis=true
              name="Other blockchains"
              size="2TB+"
              label="Increasing"
              textColor=Style.Colors.purpleBrown>
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
          marginTop(`rem(1.5)),
          justifyContent(`spaceAround),
          flexWrap(`wrap),
          media(Style.MediaQuery.full, [marginTop(`rem(4.5))]),
        ])
      )>
      <Copy />
      <Graphic />
    </div>,
};
();
