open Tc;

module Styles = {
  open Css;
  let errorText =
    merge([Theme.Text.Body.regular, style([color(Theme.Colors.roseBud)])]);
};

type unvalidatedModalState = {
  fromStr: option(PublicKey.t),
  toStr: string,
  amountStr: string,
  feeStr: string,
  memoOpt: option(string),
  errorOpt: option(string),
};

let emptyModal = activeWallet => {
  fromStr: activeWallet,
  toStr: "",
  amountStr: "",
  feeStr: "",
  memoOpt: None,
  errorOpt: None,
};

[@react.component]
let make = (~wallets, ~onSubmit) => {
  let (sendState, setModalState) = React.useState(_ => None);
  let (settings, _updateSettings) =
    React.useContext(SettingsProvider.context);
  let activeWallet = Hooks.useActiveWallet();
  let spacer = <Spacer height=0.5 />;

  <>
    <Button
      label="Send"
      onClick={_ => setModalState(_ => Some(emptyModal(activeWallet)))}
    />
    {switch (sendState) {
     | None => React.null
     | Some(
         {fromStr, toStr, amountStr, feeStr, memoOpt, errorOpt} as fullState,
       ) =>
       <Modal
         title="Send Coda" onRequestClose={() => setModalState(_ => None)}>
         <div
           className=Css.(
             style([
               display(`flex),
               width(`percent(100.)),
               flexDirection(`column),
               alignItems(`center),
               justifyContent(`center),
             ])
           )>
           {switch (errorOpt) {
            | None => React.null
            | Some(err) =>
              <div className=Styles.errorText>
                {React.string("Error: " ++ err)}
              </div>
            }}
           spacer
           <Dropdown
             label="From"
             value=fromStr
             onChange={value =>
               setModalState(Option.map(~f=s => {...s, fromStr: value}))
             }
             options={
               wallets
               |> Array.map(~f=wallet =>
                    (
                      wallet.Wallet.key,
                      SettingsRenderer.getWalletName(settings, wallet.key),
                    )
                  )
               |> Array.toList
             }
           />
           spacer
           <TextField
             label="To"
             onChange={value =>
               setModalState(Option.map(~f=s => {...s, toStr: value}))
             }
             value=toStr
             placeholder="Recipient Public Key"
           />
           spacer
           <TextField
             isCurrency=true
             label="QTY"
             onChange={value =>
               setModalState(Option.map(~f=s => {...s, amountStr: value}))
             }
             value=amountStr
             placeholder="0"
           />
           spacer
           <TextField
             isCurrency=true
             label="Fee"
             onChange={value =>
               setModalState(Option.map(~f=s => {...s, feeStr: value}))
             }
             value=feeStr
             placeholder="0"
           />
           spacer
           {switch (memoOpt) {
            | None =>
              <div className=Css.(style([alignSelf(`flexEnd)]))>
                <Link
                  onClick={_ =>
                    setModalState(
                      Option.map(~f=s => {...s, memoOpt: Some("")}),
                    )
                  }>
                  {React.string("+ Add memo")}
                </Link>
              </div>
            | Some(memoStr) =>
              <TextField
                label="Memo"
                onChange={value =>
                  setModalState(
                    Option.map(~f=s => {...s, memoOpt: Some(value)}),
                  )
                }
                value=memoStr
                placeholder="Thanks!"
              />
            }}
           <Spacer height=1.0 />
           <div className=Css.(style([display(`flex)]))>
             <Button
               label="Cancel"
               style=Button.Gray
               onClick={_ => setModalState(_ => None)}
             />
             <Spacer width=1. />
             <Button
               label="Send"
               style=Button.Green
               onClick={_ =>
                 onSubmit(
                   fullState,
                   fun
                   | Some(err) =>
                     setModalState(
                       Option.map(~f=s => {...s, errorOpt: Some(err)}),
                     )
                   | None => setModalState(_ => None),
                 )
               }
             />
           </div>
         </div>
       </Modal>
     }}
  </>;
};
