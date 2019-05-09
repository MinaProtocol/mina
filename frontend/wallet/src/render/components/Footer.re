open Tc;

module Styles = {
  open Css;

  let footer =
    style([
      position(`fixed),
      bottom(`px(0)),
      left(`px(0)),
      right(`px(0)),
      display(`flex),
      height(Theme.Spacing.footerHeight),
      justifyContent(`spaceBetween),
      alignItems(`center),
      padding2(~v= `px(0), ~h= `rem(2.)),
      borderTop(`px(1), `solid, Theme.Colors.borderColor),
    ]);
};

module StakingSwitch = {
  [@react.component]
  let make = (~pubKey) => {
    let context = React.useContext(SettingsProvider.context);
    <div className=Css.(style([color(Theme.Colors.serpentine)]))>
      <input
        type_="checkbox"
        label="staking-switch"
        checked=true
        onChange={_e => Js.log("TODO: Implement stake changing")}
      />
      <span> {ReasonReact.string("Staking")} </span>
      <span className=Css.(style([fontFamily("Menlo")]))>
        {ReasonReact.string({j| ⚡︎ |j})}
      </span>
      <span>
        {ReasonReact.string(
          Tc.Option.andThen(~f=(s => SettingsRenderer.lookup(s, pubKey)), context.settings)
          |> Option.withDefault(~default=pubKey |> PublicKey.toString)
        )}
      </span>
    </div>;
  };
};

module ActivityLogButton = {
  [@react.component]
  let make = () => {
    <button>
      <span> {ReasonReact.string("Activity Log")} </span>
      <span className=Css.(style([marginLeft(`rem(1.0))]))>
        {ReasonReact.string({j|⌘L|j})}
      </span>
    </button>;
  };
};

module RightButtons = {
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
  let make = (~pubKeySelected) => {
    <div> <PublicKeyButton pubKeySelected /> <SendButton /> </div>;
  };
};

[@react.component]
let make = () => {
  let stakingKey = PublicKey.ofStringExn("131243123");
  <div className=Styles.footer>
    <StakingSwitch pubKey=stakingKey />
    <ActivityLogButton />
    <RightButtons pubKeySelected=None />
  </div>
};
