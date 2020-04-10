[@bs.val] [@bs.scope "window"]
external downloadCoda:
  (string, (int, int) => unit, Belt.Result.t(unit, string) => unit) => unit =
  "downloadCoda";

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

module DaemonStarter = {
  module StatusQueryString = [%graphql
    {|
      query StatusQuery {
        syncStatus
      }
    |}
  ];
  module StatusQuery = ReasonApollo.CreateQuery(StatusQueryString);

  [@react.component]
  let make = (~onFinish) => {
    // Start the daemon process if we're in managed setup
    let dispatch = React.useContext(ProcessDispatchProvider.context);
    CodaProcess.useStartEffect(Some(dispatch));

    <StatusQuery>
      {response =>
         switch (response.result) {
         | Loading => React.null
         | Error((err: ReasonApolloTypes.apolloError)) =>
           onFinish(Belt.Result.Error(err.message));
           React.null;
         | Data(_) => <p> {React.string("started")} </p>
         }}
    </StatusQuery>;
  };
};

module SuccessIcon = {
  [@react.component]
  let make = (~radius=52.) =>
       <svg width="120" height="120">
         <circle
           stroke="#00D400"
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
           d="M18.3265 38.15L0 19.8439L5.16806 14.6815L18.3265 27.7887L46.146 0L51.3141 5.19894L18.3265 38.15Z" fill="#00D400"
         />
       </svg>;
}

module ErrorIcon = {
  [@react.component]
  let make = (~radius=52.) =>
       <svg width="120" height="120" viewBox="-30 -30 120 120">
         <circle
           stroke="#EA001C"
           strokeWidth="7"
           fill="transparent"
           r={Js.Float.toString(radius)}
           cx="30"
           cy="30"
         />
         <path
           fillRule="evenodd"
           clipRule="evenodd"
           d="M0 51H59.0526L29.5263 0L0 51ZM26.842 37.5786H32.2104V42.9471H26.842V37.5786ZM26.842 21.4718H32.2104V32.2086H26.842V21.4718Z"
           fill="#D72B2A"
         />
       </svg>;

}

[@react.component]
let make = (~onFinish, ~finished, ~error) => {
  let ((downloaded, total, installed), updateState) =
    React.useState(() => (0, 1, false));

  React.useEffect0(() => {
    Bindings.(
      switch (Js.Nullable.toOption(LocalStorage.getItem(`Installed))) {
      | Some(_) => onFinish(Belt.Result.Ok())
      | None =>
        downloadCoda(
          "macos",
          (chunkSize, totalSize) =>
            updateState(((downloaded, _, installed)) =>
              (downloaded + chunkSize, totalSize, installed)
            ),
          result => {
            switch (result) {
            | Ok () =>
              updateState(((downloaded, total, _)) =>
                (downloaded, total, true)
              )
            | Error(_) => onFinish(result)
            }
          },
        )
      }
    );
    None;
  });

  let radius = 52.;
  let circumference = radius *. 2. *. Js.Math._PI;
  // Add an additional 30% to represent starting
  let percent = float_of_int(downloaded) /. (float_of_int(total) *. 1.3);
  let offset = circumference -. percent *. circumference;

  <>
    {switch (finished, error) {
     | (true, _) =>
      <SuccessIcon />
     | (false, false) =>
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
           className=Styles.progressRingCircle
           stroke="#00D400"
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
              Printf.sprintf("%.0f%%", total == 0 ? 0. : percent *. 100.),
            )}
         </text>
       </svg>
     | (_, true) =>
       <ErrorIcon />
     }}
    {installed ? <DaemonStarter onFinish /> : React.null}
  </>;
};
