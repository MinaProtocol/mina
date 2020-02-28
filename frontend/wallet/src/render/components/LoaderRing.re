module Styles = {
  open Css;
  let ring = style([alignSelf(`center)]);
  let rotate =
    keyframes([
      (0, [transform(rotate(`deg(0)))]),
      (100, [transform(rotate(`deg(360)))]),
    ]);
  let innerRing =
    style([
      animation(
        rotate,
        ~duration=2000,
        ~timingFunction=`linear,
        ~iterationCount=`infinite,
      ),
      transformOrigin(`percent(50.), `percent(50.)),
    ]);
};
[@react.component]
let make = () => {
  <div className=Styles.ring>
    <svg width="120" height="120">
      <circle
        stroke="#D8D8D8"
        strokeWidth="7"
        fill="transparent"
        r="52"
        cx="60"
        cy="60"
      />
      <circle
        stroke="#3CFF64"
        strokeWidth="7"
        fill="transparent"
        strokeDasharray="200"
        className=Styles.innerRing
        r="52"
        cx="60"
        cy="60"
      />
    </svg>
  </div>;
};
