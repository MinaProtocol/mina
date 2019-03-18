open Css;
open Style;

module Copy = {
  let component = ReasonReact.statelessComponent("HeroSection.Copy");
  let make = _ => {
    ...component,
    render: _self =>
      <div className={style([width(`percent(50.0))])}>
        <h1
          className={merge([
            H1.hero,
            style([
              marginTop(`rem(1.0)),
              media(MediaQuery.full, [marginTop(`rem(1.5))]),
            ]),
          ])}>
          {ReasonReact.string(
             "A cryptocurrency with a tiny, portable blockchain.",
           )}
        </h1>
        <p className=Body.big>
          <span>
            {ReasonReact.string(
               "Coda is the first cryptocurrency with a succinct blockchain. Out lightweight blockchain means ",
             )}
          </span>
          <span className=Body.big_semibold>
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
  module Placholder = {
    let basic =
      style([
        width(`rem(16.0)),
        height(`rem(29.0)),
        backgroundColor(Colors.greyishBrown),
      ]);
  };

  module Info = {
    let component =
      ReasonReact.statelessComponent("HeroSection.Graphic.Info");

    let make = (~sizeEmphasis, ~name, ~size, ~label, ~textColor, _children) => {
      ...component,
      render: _ =>
        <div
          className={style([
            display(`flex),
            flexDirection(`column),
            justifyContent(`spaceBetween),
            alignItems(`center),
          ])}>
          <div>
            <h3
              className={merge([
                H3.basic,
                style([color(textColor), fontWeight(`medium)]),
              ])}>
              {ReasonReact.string(name)}
            </h3>
            <h3
              className={merge([
                H3.basic,
                style([
                  color(textColor),
                  fontWeight(sizeEmphasis ? `bold : `normal),
                ]),
              ])}>
              {ReasonReact.string(size)}
            </h3>
          </div>
          <h4 className={merge([H4.basic, style([marginTop(`rem(1.5))])])}>
            {ReasonReact.string(label)}
          </h4>
        </div>,
    };
  };

  let component = ReasonReact.statelessComponent("HeroSection.Graphic");
  let make = _ => {
    ...component,
    render: _self =>
      <div className={style([width(`percent(50.0))])}>
        <div className=Placholder.basic />
        <div
          className={style([display(`flex), justifyContent(`spaceBetween)])}>
          <Info
            sizeEmphasis=false
            name="Coda"
            size="22kB"
            label="Fixed"
            textColor=Colors.bluishGreen
          />
          <Info
            sizeEmphasis=false
            name="Other blockchains"
            size="2TB+"
            label="Increasing"
            textColor=Colors.purpleBrown
          />
        </div>
      </div>,
  };
};

let component = ReasonReact.statelessComponent("HeroSection");
let make = _ => {
  ...component,
  render: _self =>
    <div
      className={style([
        display(`flex),
        marginTop(`rem(1.5)),
        media(MediaQuery.full, [marginTop(`rem(4.5))]),
      ])}>
      <Copy />
      <Graphic />
    </div>,
};
