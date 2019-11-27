[@react.component]
let make = (~width=`zero, ~height=`zero) =>
  <div
    className={Css.style([
      Css.width(width),
      Css.height(height),
      Css.flexShrink(0.),
    ])}
  />;
