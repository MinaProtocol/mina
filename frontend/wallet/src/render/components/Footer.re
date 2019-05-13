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
  let make = () => {
    let (staking, setStaking) = React.useState(() => true);
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
          merge([
            Theme.Text.body,
            style([
              color(staking ? Theme.Colors.serpentine : Theme.Colors.slateAlpha(0.7)),
              marginLeft(`rem(1.)),
            ])])
        )>
        {ReasonReact.string("Earn Coda > Vault")}
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
  <div className=Styles.footer>
    <StakingSwitch />
    <div> <PublicKeyButton pubKeySelected=None /> <SendButton /> </div>
  </div>;
};
