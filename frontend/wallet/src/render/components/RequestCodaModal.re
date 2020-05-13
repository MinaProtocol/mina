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
let make = (~accounts, ~setModalState) => {
  let activePublicKey = Hooks.useActiveAccount();
  let (selectedAccount, setSelectedAccount) =
    React.useState(() => activePublicKey);
  let toast = Hooks.useToast();
  let handleClipboard = (~account, _) => {
    Bindings.Navigator.Clipboard.writeTextTask(PublicKey.toString(account))
    |> Task.perform(~f=_ => setModalState(_ => false));
    toast("Copied public key to clipboard", ToastProvider.Default);
  };
  <Modal title="Request Coda" onRequestClose={() => setModalState(_ => false)}>
    <div className=Modal.Styles.default>
      <div className=Styles.bodyMargin>
        <Dropdown
          label="To"
          value={Option.map(~f=PublicKey.toString, selectedAccount)}
          onChange={value =>
            setSelectedAccount(_ => Some(PublicKey.ofStringExn(value)))
          }
          options={
            accounts
            |> Array.map(~f=account =>
                 (
                   PublicKey.toString(account.Account.publicKey),
                   <AccountDropdownItem account />,
                 )
               )
            |> Array.toList
          }
        />
        <Spacer height=1. />
        {switch (selectedAccount) {
         | None => React.null
         | Some(selectedAccount) =>
           <div className=Styles.publicKey>
             {React.string(PublicKey.toString(selectedAccount))}
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
        {switch (selectedAccount) {
         | None =>
           <Button
             label="Copy public key"
             style=Button.HyperlinkBlue
             disabled=true
           />
         | Some(selectedAccount) =>
           <Button
             label="Copy public key"
             style=Button.HyperlinkBlue
             onClick={handleClipboard(~account=selectedAccount)}
           />
         }}
      </div>
    </div>
  </Modal>;
};
