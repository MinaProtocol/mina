// TODO: On mobile left align

let component = ReasonReact.statelessComponent("Title");
let make = (~noBottomMargin=false, ~fontColor, ~text, _children) => {
  ...component,
  render: _self =>
    <div
      className=Css.(
        style([
          media(
            Style.MediaQuery.notMobile,
            [
              display(`flex),
              justifyContent(`center),
              width(`percent(100.0)),
            ],
          ),
          ...noBottomMargin ? [] : [marginBottom(`rem(2.25))],
        ])
      )>
      <h1
        className=Css.(
          merge([
            Style.H1.hero,
            style([
              marginTop(`zero),
              marginBottom(`zero),
              display(`inlineBlock),
              color(fontColor),
              maxWidth(`rem(30.0)),
              media(Style.MediaQuery.full, [maxWidth(`percent(100.0))]),
            ]),
          ])
        )>
        {ReasonReact.string(text)}
      </h1>
    </div>,
};
