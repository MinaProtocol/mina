module Investor = {
  let component = ReasonReact.statelessComponent("BuiltBy.Investor");
  let make = (~name, ~suffix, _) => {
    let firstName = Js.String.split(" ", name)[0];
    let suffixStr =
      switch (suffix) {
      | `Png => "png"
      | `Jpg => "jpg"
      };
    let imageSrc =
      "/static/img/investors/"
      ++ String.lowercase(firstName)
      ++ "."
      ++ suffixStr;
    {
      ...component,
      render: _self =>
        <div
          className=Css.(
            style([
              display(`flex),
              flexDirection(`row),
              alignItems(`center),
            ])
          )>
          <img
            src=imageSrc
            className=Css.(
              style([
                maxWidth(`rem(2.5)),
                maxHeight(`rem(2.5)),
                borderRadius(`percent(100.)),
                marginRight(`em(1.)),
              ])
            )
          />
          <h4
            className=Css.(
              merge([Style.Body.basic, style([color(Style.Colors.slate)])])
            )>
            {ReasonReact.string(name)}
          </h4>
        </div>,
    };
  };
};

let component = ReasonReact.statelessComponent("BuiltBy");
let make = _children => {
  ...component,
  render: _self =>
    <div>
      <h3 className=Style.H3.wide> {ReasonReact.string("Investors")} </h3>
      <div
        className=Css.(
          style([
            maxWidth(`rem(64.)),
            display(`grid),
            gridGap(`rem(1.)),
            marginLeft(`auto),
            marginRight(`auto),
            // bs-css doesn't allow fr in minmax: https://github.com/SentiaAnalytics/bs-css/pull/124
            `declaration((
              "grid-template-columns",
              "repeat(auto-fill, minmax(15rem, 1fr))",
            )),
          ])
        )>
        <Investor name="Metastable" suffix=`Png />
        <Investor name="Polychain Capital" suffix=`Jpg />
        <Investor name="ScifiVC" suffix=`Png />
        <Investor name="Dekrypt Capital" suffix=`Png />
        <Investor name="Electric Capital" suffix=`Png />
        <Investor name="Curious Endeavors" suffix=`Jpg />
        <Investor name="Kindred Ventures" suffix=`Png />
        <Investor name="Caffeinated Capital" suffix=`Png />
        <Investor name="Naval Ravikant" suffix=`Png />
        <Investor name="Elad Gil" suffix=`Jpg />
        <Investor name="Linda Xie" suffix=`Jpg />
        <Investor name="Fred Ehrsam" suffix=`Jpg />
        <Investor name="Jack Herrick" suffix=`Jpg />
        <Investor name="Nima Capital" suffix=`Png />
        <Investor name="Charlie Noyes" suffix=`Png />
        <Investor name="O Group" suffix=`Png />
      </div>
    </div>,
};
