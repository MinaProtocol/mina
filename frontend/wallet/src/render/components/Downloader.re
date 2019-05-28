[@bs.val] [@bs.scope "window"]
external downloadKey:
  (string, (int, int) => unit, Belt.Result.t(unit, string) => unit) => unit =
  "";

[@react.component]
let make = (~keyName, ~onFinish) => {
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

  <div>
    {React.string(
       Printf.sprintf(
         "Downloaded %.1f%% of %dmb.",
         total == 0
           ? 0. : float_of_int(downloaded) /. float_of_int(total) *. 100.,
         total / 1000000,
       ),
     )}
  </div>;
};
