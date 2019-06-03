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
    let (settings, _updateAddressBook) = React.useContext(AddressBookProvider.context);
    let activePublicKey = Hooks.useActiveWallet();
    let (selectedWallet, setSelectedWallet) = React.useState(() => activePublicKey);
    let keyString = switch (selectedWallet) {
      | None => ""
      | Some(wallet) => PublicKey.toString(wallet)
    };
    <Modal 
      title="Request Coda"
      onRequestClose={() => setModalState(_ => None)}
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
            value=selectedWallet
            onChange={value => setSelectedWallet(_ => value)}
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
          <div className=Styles.publicKey>
            {React.string(keyString)}
          </div>
        </div>
        <div className=Css.(style([display(`flex)]))>
          <Button
            label="Cancel"
            style=Button.Gray
            onClick={_ => setModalState(_ => None)}
          />
          <Spacer width=1. />
          <Button
            label="Copy public key"
            style=Button.Blue
            onClick={_ => {
              Bindings.Navigator.Clipboard.writeText(keyString)
              |> Js.Promise.then_(_value => {
                  Js.log("Public key copied to clipboard");
                  Js.Promise.resolve(1);
                })
              |> Js.Promise.catch(err => {
                  Js.log2("Error copying to clipboard", err);
                  Js.Promise.resolve(2);
                })
              |> ignore;
              setModalState(_ => None);
            }}
          />
        </div>
      </div>
    </Modal>;
  };
  