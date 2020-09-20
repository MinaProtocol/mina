open Css;

[@react.component]
let make = (~overflowHidden=false, ~children) => {
  let paddingX = m => [paddingLeft(m), paddingRight(m)];
  <div
    className={style(
      (overflowHidden ? [overflow(`hidden)] : [])
      @ [
        margin(`auto),
        media(
          Theme.MediaQuery.desktop,
          [maxWidth(`rem(90.0)), ...paddingX(`rem(9.5))],
        ),
        media(
          Theme.MediaQuery.tablet,
          [maxWidth(`rem(80.0)), ...paddingX(`rem(2.5))],
        ),
        ...paddingX(`rem(1.5)),
      ],
    )}>
    children
  </div>;
};
