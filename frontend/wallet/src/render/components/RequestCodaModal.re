open Tc;

module Styles = {
  open Css;

  let bodyMargin = style([margin(`rem(1.0)), width(`percent(100.))]);

  let publicKey =
    merge([
      Theme.Text.Body.regular,
      style([
        border(`px(1), `solid, Theme.Colors.marineAlpha(0.3)),
        borderRadius(`rem(0.25)),
        padding(`px(12)),
        backgroundColor(white),
        wordWrap(`breakWord),
        userSelect(`text),
        color(Theme.Colors.midnightBlue),
      ]),
    ]);
};

[@react.component]
let make = (~wallets, ~setModalState) => {
  let activePublicKey = Hooks.useActiveWallet();
  let (selectedWallet, setSelectedWallet) =
    React.useState(() => activePublicKey);
  let handleClipboard = (~wallet, _) =>
    Bindings.Navigator.Clipboard.writeTextTask(PublicKey.toString(wallet))
    |> Task.perform(~f=() => setModalState(_ => false));
  <Modal title="Request Coda" onRequestClose={() => setModalState(_ => false)}>
    <div className=Modal.Styles.default>
      <div className=Styles.bodyMargin>
        <Dropdown
          label="To"
          value={Option.map(~f=PublicKey.toString, selectedWallet)}
          onChange={value =>
            setSelectedWallet(_ => Some(PublicKey.ofStringExn(value)))
          }
          options={
            wallets
            |> Array.map(~f=wallet =>
                 (
                   PublicKey.toString(wallet.Wallet.publicKey),
                   <WalletDropdownItem wallet />,
                 )
               )
            |> Array.toList
          }
        />
        <Spacer height=1. />
        {switch (selectedWallet) {
         | None => React.null
         | Some(selectedWallet) =>
           <div className=Styles.publicKey>
             {React.string(PublicKey.toString(selectedWallet))}
           </div>
         }}
      </div>
      <div className=Css.(style([display(`flex)]))>
        <Button
          label="Cancel"
          style=Button.Gray
          onClick={_ => setModalState(_ => false)}
        />
        <Spacer width=1. />
        {switch (selectedWallet) {
         | None =>
           <Button label="Copy public key" style=Button.Blue disabled=true />
         | Some(selectedWallet) =>
           <Button
             label="Copy public key"
             style=Button.Blue
             onClick={handleClipboard(~wallet=selectedWallet)}
           />
         }}
      </div>
    </div>
  </Modal>;
};
