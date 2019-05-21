module Button = {
  [@react.component]
  let make = (~className="", ~onClick, ~bgColor, ~copy) => {
    <button
      onClick
      className=Css.(
        merge([
          className,
          style([
            backgroundColor(bgColor),
            color(Theme.Colors.blanco),
            paddingLeft(`rem(2.0)),
            paddingRight(`rem(2.0)),
            paddingTop(`rem(1.0)),
            paddingBottom(`rem(1.0)),
            borderRadius(`px(6)),
            border(`zero, `none, Css.white),
          ]),
        ])
      )>
      {ReasonReact.string(copy)}
    </button>;
  };
};

[@react.component]
let make = (~onSecondaryClick, ~onPrimaryClick, ~primaryColor, ~primaryCopy) => {
  <div
    className=Css.(
      style([
        display(`flex),
        justifyContent(`spaceBetween),
        alignItems(`center),
      ])
    )>
    <Button
      className=Css.(style([marginRight(`rem(1.0))]))
      onClick=onSecondaryClick
      bgColor={Theme.Colors.slateAlpha(0.3)}
      copy="Cancel"
    />
    <Button onClick=onPrimaryClick bgColor=primaryColor copy=primaryCopy />
  </div>;
};
