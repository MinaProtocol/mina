[@react.component]
let make = (~view) => {
  switch (view) {
  | None => <span />
  | Some(view) =>
    <div
      className=Css.(
        style([
          position(`absolute),
          left(`zero),
          top(`zero),
          display(`flex),
          justifyContent(`center),
          alignItems(`center),
          width(`percent(100.)),
          height(`percent(100.)),
          backgroundColor(Theme.Colors.savilleAlpha(0.95)),
        ])
      )
      onClick={_ => Router.navigate(Home)}>
      view
    </div>
  };
};
