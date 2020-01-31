module Styles = {
  open Css;

  let container = style([display(`flex), height(`rem(2.))]);

  let button = active_ =>
    merge([
      Theme.Text.Header.h6,
      style([
        background(active_ ? Theme.Colors.hyperlink : Theme.Colors.gandalf),
        color(active_ ? white : Theme.Colors.slate),
        textTransform(`uppercase),
        textShadow(~y=active_ ? `px(1) : `zero, Theme.Colors.slate),
        flexGrow(1.),
        flexBasis(`zero),
        height(`percent(100.)),
        border(`px(0), `solid, white),
        boxShadow(
          ~blur=active_ ? `rem(0.5) : `zero,
          Theme.Colors.hyperlinkAlpha(0.3),
        ),
        active([outlineStyle(`none)]),
        focus([outlineStyle(`none)]),
        disabled([pointerEvents(`none)]),
        hover([opacity(0.8)]),
        firstChild([
          borderTopLeftRadius(`rem(0.25)),
          borderBottomLeftRadius(`rem(0.25)),
        ]),
        lastChild([
          borderTopRightRadius(`rem(0.25)),
          borderBottomRightRadius(`rem(0.25)),
        ]),
      ]),
    ]);
};

module Group = {
  [@react.component]
  let make = (~children) => <div className=Styles.container> children </div>;
};

[@react.component]
let make = (~options, ~selected, ~onChange) => {
  <div className=Styles.container>
    {Array.mapi(
       (i, option_) =>
         <button
           key={string_of_int(i) ++ option_}
           className={Styles.button(i == selected)}
           onClick={_e => onChange(i)}>
           {React.string(option_)}
         </button>,
       options,
     )
     |> React.array}
  </div>;
};
