open Tc;

module Styles = {
  open Css;

  let footer =
    style([
      position(`fixed),
      bottom(`zero),
      left(`zero),
      right(`zero),
      display(`flex),
      height(Theme.Spacing.footerHeight),
      justifyContent(`spaceBetween),
      alignItems(`center),
      padding2(~v=`zero, ~h=`rem(2.)),
      borderTop(`px(1), `solid, Theme.Colors.borderColor),
    ]);
};

module StakingSwitch = {
  [@react.component]
  let make = (~pubKey) => {
    let (staking, setStaking) = React.useState(() => true);
    let (settings, _) = React.useContext(SettingsProvider.context);
    <div
      className=Css.(
        style([
          color(Theme.Colors.serpentine),
          display(`flex),
          alignItems(`center),
        ])
      )>
      <Toggle value=staking onChange={_e => setStaking(staking => !staking)} />
      <span
        className=Css.(
          style([
            Theme.Typeface.sansSerif,
            lineHeight(`rem(1.5)),
            marginLeft(`rem(1.)),
          ])
        )>
        {ReasonReact.string("Earn Coda > Vault")}
      </span>
      <span>
        {ReasonReact.string(
           settings
           |> Option.andThen(~f=s => SettingsRenderer.lookup(s, pubKey))
           |> Option.withDefault(~default=pubKey |> PublicKey.toString),
         )}
      </span>
    </div>;
  };
};

module PublicKeyButton = {
  [@react.component]
  let make = (~pubKeySelected) => {
    let str = ReasonReact.string("Copy public key");
    // The switch is over the <button> rather than within the onClick because
    // if there exists an onClick the button is no longer disabled (despite
    // disabled being true), and there is no way to give JSX an `option` for
    // the click handler.
    switch (pubKeySelected) {
    | Some(pubKey) =>
      <button
        onClick={_e => {
          let task =
            Bindings.Navigator.Clipboard.writeTextTask(
              PublicKey.toString(pubKey),
            );
          Task.perform(task, ~f=()
            // TODO: Should we toast when this happens? Do we need to handle errors?
            => Js.log("Copied to clipboard"));
        }}
        disabled=false>
        str
      </button>
    | None => <button disabled=true> str </button>
    };
  };
};

module SendButton = {
  [@react.component]
  let make = () => {
    <button onClick={_e => Router.navigate(Route.Send)}>
      {ReasonReact.string("Send")}
    </button>;
  };
};

[@react.component]
let make = () => {
  let stakingKey = PublicKey.ofStringExn("131243123");
  <div className=Styles.footer>
    <StakingSwitch pubKey=stakingKey />
    <div> <PublicKeyButton pubKeySelected=None /> <SendButton /> </div>
  </div>;
};
