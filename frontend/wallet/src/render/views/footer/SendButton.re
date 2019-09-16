open Tc;

module Styles = {
  open Css;

  let contentContainer =
    style([
      display(`flex),
      width(`percent(100.)),
      flexDirection(`column),
      alignItems(`center),
      justifyContent(`center),
    ]);
};

module ModalState = {
  module Validated = {
    type t = {
      from: PublicKey.t,
      to_: PublicKey.t,
      amount: string,
      fee: string,
      memoOpt: option(string),
    };
  };
  module Unvalidated = {
    type t = {
      fromStr: option(string),
      toStr: string,
      amountStr: string,
      feeStr: string,
      memoOpt: option(string),
      errorOpt: option(string),
    };
  };
};

let emptyModal: option(PublicKey.t) => ModalState.Unvalidated.t =
  activeWallet => {
    fromStr: Option.map(~f=PublicKey.toString, activeWallet),
    toStr: "",
    amountStr: "",
    feeStr: "",
    memoOpt: None,
    errorOpt: None,
  };

let validateInt64 = s =>
  switch (Int64.of_string(s)) {
  | i => i > Int64.zero
  | exception (Failure(_)) => false
  };

let validatePubkey = s =>
  switch (PublicKey.ofStringExn(s)) {
  | k => Some(k)
  | exception _ => None
  };

let validate:
  ModalState.Unvalidated.t => Belt.Result.t(ModalState.Validated.t, string) =
  state =>
    switch (state, validatePubkey(state.toStr)) {
    | ({fromStr: None}, _) => Error("Please specify a wallet to send from.")
    | ({toStr: ""}, _) => Error("Please specify a destination address.")
    | (_, None) => Error("Destination is invalid public key.")
    | ({amountStr}, _) when !validateInt64(amountStr) =>
      Error("Please specify a non-zero amount.")
    | ({feeStr}, _) when !validateInt64(feeStr) =>
      Error("Please specify a non-zero fee.")
    | ({fromStr: Some(fromPk), amountStr, feeStr, memoOpt}, Some(toPk)) =>
      Ok({
        from: PublicKey.ofStringExn(fromPk),
        to_: toPk,
        amount: amountStr,
        fee: feeStr,
        memoOpt,
      })
    };

let modalButtons = (unvalidated, setModalState, onSubmit) => {
  let setError = e =>
    setModalState(
      Option.map(~f=s => {...s, ModalState.Unvalidated.errorOpt: Some(e)}),
    );

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
        switch (validate(unvalidated)) {
        | Error(e) => setError(e)
        | Ok(validated) =>
          onSubmit(
            validated,
            fun
            | Belt.Result.Error(e) => setError(e)
            | Ok () => setModalState(_ => None),
          )
        }
      }
    />
  </div>;
};

[@react.component]
let make = (~wallets, ~onSubmit) => {
  let (sendState, setModalState) = React.useState(_ => None);
  let activeWallet = Hooks.useActiveWallet();
  
  // Check if active wallet is locked 
  
  let spacer = <Spacer height=0.5 />;
  ModalState.Unvalidated.(
    <>
      <Button
        label="Send"
        onClick={_ => setModalState(_ => Some(emptyModal(activeWallet)))}
        icon=Icon.Lock >
      </Button>
      {switch (sendState) {
       | None => React.null
       | Some(
           {fromStr, toStr, amountStr, feeStr, memoOpt, errorOpt} as fullState,
         ) =>
         <Modal
           title="Send Coda" onRequestClose={() => setModalState(_ => None)}>
           <div className=Styles.contentContainer>
             {switch (errorOpt) {
              | None => React.null
              | Some(err) => <Alert kind=`Danger message=err />
              }}
             spacer
             <Dropdown
               label="From"
               value=fromStr
               onChange={value =>
                 setModalState(
                   Option.map(~f=s => {...s, fromStr: Some(value)}),
                 )
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
             spacer
             <TextField
               label="To"
               mono=true
               onChange={value =>
                 setModalState(Option.map(~f=s => {...s, toStr: value}))
               }
               value=toStr
               placeholder="Recipient Public Key"
             />
             spacer
             <TextField.Currency
               label="QTY"
               onChange={value =>
                 setModalState(Option.map(~f=s => {...s, amountStr: value}))
               }
               value=amountStr
               placeholder="0"
             />
             spacer
             <TextField.Currency
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
                    kind=Link.Blue
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
             {modalButtons(fullState, setModalState, onSubmit)}
           </div>
         </Modal>
       }}
    </>
  );
};
