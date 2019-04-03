let twoColumnMedia = "(min-width: 34rem)";

module Investor = {
  let component = ReasonReact.statelessComponent("Investors.Investor");
  let make = (~name, _) => {
    ...component,
    render: _self =>
      <div
        className=Css.(
          style([
            display(`flex),
            alignItems(`center),
            backgroundColor(Style.Colors.greyish),
            height(`rem(1.75)),
            marginRight(`rem(0.75)),
            marginBottom(`rem(0.625)),
          ])
        )>
        // Note: change this alt text if we ever hide the investor name

          <h4
            className=Css.(
              merge([
                Style.H3.Technical.title,
                style([
                  marginTop(`rem(0.0625)),
                  ...Style.paddingX(`rem(0.1875)),
                ]),
              ])
            )>
            {ReasonReact.string(name)}
          </h4>
        </div>,
  };
};

let component = ReasonReact.statelessComponent("Investors");
let make = _children => {
  ...component,
  render: _self =>
    <div>
      <h3 className=Style.H3.Technical.boxed>
        {ReasonReact.string("O(1) Investors")}
      </h3>
      <div
        className=Css.(
          style([
            maxWidth(`rem(78.)),
            display(`flex),
            flexWrap(`wrap),
            marginTop(`rem(3.)),
            marginLeft(`auto),
            marginRight(`auto),
            justifyContent(`center),
          ])
        )>
        <Investor name="Metastable" />
        <Investor name="Polychain Capital" />
        <Investor name="ScifiVC" />
        <Investor name="Dekrypt Capital" />
        <Investor name="Electric Capital" />
        <Investor name="Curious Endeavors" />
        <Investor name="Kindred Ventures" />
        <Investor name="Caffeinated Capital" />
        <Investor name="Naval Ravikant" />
        <Investor name="Elad Gil" />
        <Investor name="Linda Xie" />
        <Investor name="Fred Ehrsam" />
        <Investor name="Jack Herrick" />
        <Investor name="Nima Capital" />
        <Investor name="Charlie Noyes" />
        <Investor name="O Group" />
      </div>
    </div>,
};
