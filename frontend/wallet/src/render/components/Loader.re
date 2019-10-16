module Page = {
  [@react.component]
  let make = (~children) =>
    <div
      className=Css.(
        style([
          width(`percent(100.)),
          height(`percent(100.)),
          display(`flex),
          alignItems(`center),
          justifyContent(`center),
        ])
      )>
      children
    </div>;
};

module Styles = {
  open Css;

  let container =
    style([
      position(`relative),
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
      color(Theme.Colors.slateAlpha(0.4)),
    ]);

  let bigSqureShrink =
    keyframes([
      (0, [transform(scale(1., 1.))]),
      (90, [transform(scale(1., 1.))]),
      (100, [transform(scale(0.5, 0.5))]),
    ]);

  let bigSquare =
    style([
      position(`relative),
      display(`inlineBlock),
      width(`px(32)),
      height(`px(32)),
      overflow(`hidden),
      transformOrigin(`percent(0.), `percent(100.)),
      animationName(bigSqureShrink),
      animationDuration(1000),
      animationTimingFunction(`linear),
      animationIterationCount(`infinite),
    ]);

  let square =
    style([
      position(`absolute),
      width(`px(16)),
      height(`px(16)),
      backgroundColor(`currentColor),
    ]);

  let first = style([left(`px(0)), top(`px(16))]);

  let drop2 =
    keyframes([
      (0, [transform(translateY(`px(-50)))]),
      (25, [transform(translate(`zero, `zero))]),
      (100, [transform(translate(`zero, `zero))]),
    ]);

  let drop3 =
    keyframes([
      (0, [transform(translateY(`px(-50)))]),
      (50, [transform(translate(`zero, `zero))]),
      (100, [transform(translate(`zero, `zero))]),
    ]);

  let drop4 =
    keyframes([
      (0, [transform(translateY(`px(-50)))]),
      (75, [transform(translate(`zero, `zero))]),
      (100, [transform(translate(`zero, `zero))]),
    ]);

  let second =
    style([
      left(`px(16)),
      top(`px(16)),
      animation(
        drop2,
        ~duration=1000,
        ~timingFunction=`linear,
        ~iterationCount=`infinite,
      ),
    ]);

  let third =
    style([
      left(`px(0)),
      top(`px(0)),
      animation(
        drop3,
        ~duration=1000,
        ~timingFunction=`linear,
        ~iterationCount=`infinite,
      ),
    ]);

  let fourth =
    style([
      left(`px(16)),
      top(`px(0)),
      animation(
        drop4,
        ~duration=1000,
        ~timingFunction=`linear,
        ~iterationCount=`infinite,
      ),
    ]);
};

[@react.component]
let make = (~hideText=false) =>
  <div className=Styles.container>
    <div className=Styles.bigSquare>
      <div className={Css.merge([Styles.square, Styles.first])} />
      <div className={Css.merge([Styles.square, Styles.second])} />
      <div className={Css.merge([Styles.square, Styles.third])} />
      <div className={Css.merge([Styles.square, Styles.fourth])} />
    </div>
    {hideText
       ? React.null
       : <>
           <Spacer height=0.25 />
           <span className=Theme.Text.Body.semiBold>
             {React.string("Loading...")}
           </span>
         </>}
  </div>;
