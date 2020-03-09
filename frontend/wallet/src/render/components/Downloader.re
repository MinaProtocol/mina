[@bs.val] [@bs.scope "window"]
external downloadKey:
  (string, (int, int) => unit, Belt.Result.t(unit, string) => unit) => unit =
  "";

module Styles = {
  open Css;
  let progressRingCircle =
    style([
      transition(~duration=0, "stroke-dashoffset"),
      transform(rotate(`deg(-90))),
      transformOrigin(`percent(50.), `percent(50.)),
    ]);
  let progressText =
    merge([Theme.Text.Header.h1, style([fontSize(`rem(2.))])]);
};

[@react.component]
let make = (~keyName, ~onFinish, ~finished) => {
  let ((downloaded, total), updateState) = React.useState(() => (0, 0));

  React.useEffect0(() => {
    downloadKey(
      keyName,
      (chunkSize, totalSize) =>
        updateState(((downloaded, _)) =>
          (downloaded + chunkSize, totalSize)
        ),
      onFinish,
    );
    None;
  });

  let radius = 52.;
  let circumference = radius *. 2. *. Js.Math._PI;
  let percent = float_of_int(downloaded) /. float_of_int(total);
  let offset = circumference -. percent *. circumference;

  finished
    ? <svg width="120" height="120">
        <circle
          stroke="#3CFF64"
          strokeWidth="7"
          fill="transparent"
          r={Js.Float.toString(radius)}
          cx="60"
          cy="60"
        />
        <path
          transform="translate(35,40)"
          fillRule="evenodd"
          clipRule="evenodd"
          d="M18.3265 38.15L0 19.8439L5.16806 14.6815L18.3265 27.7887L46.146 0L51.3141 5.19894L18.3265 38.15Z"
          fill="#00D400"
        />
      </svg>
    : <svg width="120" height="120">
        <circle
          stroke="#D8D8D8"
          strokeWidth="7"
          fill="transparent"
          r="52"
          cx="60"
          cy="60"
        />
        <circle
          className=Styles.progressRingCircle
          stroke="#3CFF64"
          strokeWidth="7"
          strokeDasharray={
            Js.Float.toString(circumference)
            ++ " "
            ++ Js.Float.toString(circumference)
          }
          strokeDashoffset={Js.Float.toString(offset)}
          fill="transparent"
          r={Js.Float.toString(radius)}
          cx="60"
          cy="60"
        />
        <text
          x="50%"
          y="60%"
          textAnchor="middle"
          className=Styles.progressText
          fill="white">
          {React.string(
             Printf.sprintf(
               "%.0f%%",
               total == 0
                 ? 0.
                 : float_of_int(downloaded) /. float_of_int(total) *. 100.,
             ),
           )}
        </text>
      </svg>;
};
