// TODO: On mobile left align

[@react.component]
let make = (~noBottomMargin=false, ~fontColor, ~text) => {
  <div
    className=Css.(
      style([
        media(
          Theme.MediaQuery.notMobile,
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
          Theme.H1.hero,
          style([
            marginTop(`zero),
            marginBottom(`zero),
            display(`inlineBlock),
            color(fontColor),
            maxWidth(`rem(30.0)),
            media(Theme.MediaQuery.full, [maxWidth(`percent(100.0))]),
          ]),
        ])
      )>
      {React.string(text)}
    </h1>
  </div>;
};
