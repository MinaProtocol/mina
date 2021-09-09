module Styles = {
  open Css;
  let fadeIn =
    keyframes([
      (0, [opacity(0.), top(`rem(1.0))]),
      (100, [opacity(1.), top(`zero)]),
    ]);

  let animate = (duration, delay) =>
    style([
      position(`relative),
      opacity(0.),
      animation(fadeIn, ~duration, ~iterationCount=`count(1)),
      animationDelay(delay),
      animationFillMode(`forwards),
    ]);
};
[@react.component]
let make = (~children, ~duration, ~delay=0) =>
  <div className=Css.(style([position(`relative)]))>
    <div className={Styles.animate(duration, delay)}> children </div>
  </div>;
