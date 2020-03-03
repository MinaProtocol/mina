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
  let timerText =
    merge([Theme.Text.Header.h4, style([fontSize(`rem(1.5))])]);
};
[@react.component]
let make = () => {
  let initialTime = Js.Math.floor(Js.Date.now());

  let (timeSinceInitial, setTimeSinceInitial) =
    React.useState(() => Js.Math.floor(Js.Date.now()) - initialTime);
  let (minutesSinceInitial, setMinutes) =
    React.useState(() => timeSinceInitial / 60);
  let (secondsPart, setSeconds) =
    React.useState(() => timeSinceInitial mod 60);
  React.useEffect0(() => {
    let timerId =
      Js.Global.setInterval(
        () => {
          Js.log(initialTime);
          setTimeSinceInitial(_ =>
            Js.Math.floor(Js.Date.now()) - initialTime
          );
          setMinutes(_ => timeSinceInitial / 60);
          setSeconds(_ => timeSinceInitial mod 60);
          ();
        },
        1000,
      );
    Some(() => Js.Global.clearInterval(timerId));
  });

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
      <text x="20" y="55" fill="white" className=Theme.Text.Header.h4>
        {React.string("Elapsed Time")}
      </text>
      <text x="40" y="80" fill="white" className=Styles.timerText>
        {React.string(
           Js.Int.toString(minutesSinceInitial)
           ++ ":"
           ++ Js.Int.toString(secondsPart),
         )}
      </text>
    </svg>
  </div>;
};
