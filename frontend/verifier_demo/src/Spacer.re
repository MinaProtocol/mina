[@react.component]
let make = (~width=0., ~height=0.) =>
  <div
    className={Css.style([
      Css.width(`rem(width)),
      Css.height(`rem(height)),
      Css.flexShrink(0.),
    ])}
  />;
