module Styles = {
    open Css;
    let fadeIn =
    keyframes([
      (0, [opacity(0.), top(`px(50))]),
      (100, [opacity(1.), top(`px(0))]),
    ]);
    
    let animate = (duration, delay) => style([opacity(0.), animation(fadeIn, ~duration=duration, ~iterationCount=`count(1)),  animationDelay(delay), animationFillMode(`forwards),]);
    
}; 
[@react.component]
let make = (~children, ~duration, ~delay=0) =>
<div
    className={Styles.animate(duration, delay)}>
    children
</div>;

