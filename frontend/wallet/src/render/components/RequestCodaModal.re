open Tc;

module Styles = {
    open Css;
  
    let bodyMargin = style([
      margin(`rem(1.0)),
      width(`percent(100.))
    ]);

    let publicKey = merge([
      Theme.Text.Body.regular,
      style([
        border(`px(1), `solid, Theme.Colors.marineAlpha(0.3)),
        borderRadius(`rem(0.25)),
        padding(`px(12)),
        backgroundColor(white),
        wordWrap(`breakWord),
      ]),
    ]);
  };
    
  [@react.component]
  let make = (~wallets, ~setModalState) => {
    let activePublicKey = Hooks.useActiveWallet();
    let (settings, _updateAddressBook) = React.useContext(AddressBookProvider.context);
    let (selectedWallet, setSelectedWallet) = React.useState(() => activePublicKey);
    /* let keyString = PublicKey.toString(selectedWallet); */
    let keyString = switch (selectedWallet) {
      | None => ""
      | Some(selectedWallet) => PublicKey.toString(selectedWallet)
    };
    let handleClipboard = _ =>
      Bindings.Navigator.Clipboard.writeTextTask(keyString)
      |> Task.perform(~f=() => setModalState(_ => false));
    <Modal 
      title="Request Coda"
      onRequestClose={() => setModalState(_ => false)}
    >
      <div
        className=Css.(
          style([
            display(`flex),
            flexDirection(`column),
            alignItems(`center),
            justifyContent(`center),
          ])
        )>
        <div className=Styles.bodyMargin>
          /*
          TODO(PM): Add amount to options - maybe refactor 
          this into a common WalletDropdown component to use
          both here and in the send coda modal
          */
          <Dropdown
            label="To"
            value={selectedWallet}
            onChange={value => setSelectedWallet(_ => Some(value))}
            options={
              wallets
              |> Array.map(~f=wallet =>
                  (
                    wallet.Wallet.key,
                    AddressBook.getWalletName(settings, wallet.key),
                  )
                )
              |> Array.toList
            }
          />
          <Spacer height=1. />
          {switch (selectedWallet) {
          | None => React.null
          | Some(_selectedWallet) => 
            <div className=Styles.publicKey>
              {React.string(keyString)}
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
          <Button
            label="Copy public key"
            style=Button.Blue
            disabled={switch (selectedWallet) {
            | None => true
            | Some(_selectedWallet) => false
            }}
            onClick=handleClipboard
          />
        </div>
      </div>
    </Modal>;
  };
  