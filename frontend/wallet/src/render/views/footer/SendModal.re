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

module SendPayment = [%graphql
  {|
    mutation (
      $from: PublicKey!,
      $to_: PublicKey!,
      $amount: UInt64!,
      $fee: UInt64!,
      $memo: String) {
      sendPayment(input:
                    {from: $from, to: $to_, amount: $amount, fee: $fee, memo: $memo}) {
        payment {
          nonce
        }
      }
    }
  |}
];

module SendPaymentMutation = ReasonApollo.CreateMutation(SendPayment);

module ModalState = {
  module Validated = {
    type t = {
      from: PublicKey.t,
      to_: PublicKey.t,
      amountFormatted: string,
      feeFormatted: string,
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
  activeAccount => {
    fromStr: Option.map(~f=PublicKey.toString, activeAccount),
    toStr: "",
    amountStr: "",
    feeStr: "",
    memoOpt: None,
    errorOpt: None,
  };

let validateCurrency = s =>
  switch (CurrencyFormatter.ofFormattedString(s)) {
  | _ => true
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
    | ({fromStr: None}, _) =>
      Error("Please specify an account to send from.")
    | ({toStr: ""}, _) => Error("Please specify a destination address.")
    | (_, None) => Error("Destination is invalid public key.")
    | ({amountStr}, _) when !validateCurrency(amountStr) =>
      Error("Please specify a positive amount.")
    | ({feeStr}, _) when !validateCurrency(feeStr) =>
      Error("Please specify a positive fee.")
    | ({fromStr: Some(fromPk), amountStr, feeStr, memoOpt}, Some(toPk)) =>
      Ok({
        from: PublicKey.ofStringExn(fromPk),
        to_: toPk,
        amountFormatted: amountStr,
        feeFormatted: feeStr,
        memoOpt,
      })
    };

module SendForm = {
  open ModalState.Unvalidated;

  [@react.component]
  let make = (~onSubmit, ~onClose) => {
    let activeAccount = Hooks.useActiveAccount();
    let (addressBook, _) = React.useContext(AddressBookProvider.context);
    let (sendState, setModalState) =
      React.useState(_ => emptyModal(activeAccount));
    let {fromStr, toStr, amountStr, feeStr, memoOpt, errorOpt} = sendState;
    let spacer = <Spacer height=0.5 />;
    let setError = e =>
      setModalState(s => {...s, ModalState.Unvalidated.errorOpt: Some(e)});
    <form
      className=Styles.contentContainer
      onSubmit={event => {
        ReactEvent.Form.preventDefault(event);
        switch (validate(sendState)) {
        | Error(e) => setError(e)
        | Ok(validated) =>
          onSubmit(
            validated,
            fun
            | Belt.Result.Error(e) => setError(e)
            | Ok () => onClose(),
          )
        };
      }}>
      {switch (errorOpt) {
       | None => React.null
       | Some(err) => <Alert kind=`Danger defaultMessage=err />
       }}
      spacer
      // Disable dropdown, only show active Account
      <TextField
        label="From"
        value={AccountName.getName(
          Option.getExn(fromStr) |> PublicKey.ofStringExn,
          addressBook,
        )}
        disabled=true
        onChange={value => setModalState(s => {...s, fromStr: Some(value)})}
      />
      spacer
      <TextField
        label="To"
        mono=true
        onChange={value => setModalState(s => {...s, toStr: value})}
        value=toStr
        placeholder="Recipient Public Key"
      />
      spacer
      <TextField.Currency
        label="QTY"
        onChange={value => setModalState(s => {...s, amountStr: value})}
        value=amountStr
        placeholder="0"
      />
      spacer
      <TextField.Currency
        label="Fee"
        onChange={value => setModalState(s => {...s, feeStr: value})}
        value=feeStr
        placeholder="0"
      />
      spacer
      {switch (memoOpt) {
       | None =>
         <div className=Css.(style([alignSelf(`flexEnd)]))>
           <Link
             kind=Link.Blue
             onClick={_ => setModalState(s => {...s, memoOpt: Some("")})}>
             {React.string("+ Add memo")}
           </Link>
         </div>
       | Some(memoStr) =>
         <TextField
           label="Memo"
           onChange={value =>
             setModalState(s => {...s, memoOpt: Some(value)})
           }
           value=memoStr
           placeholder="Thanks!"
         />
       }}
      <Spacer height=1.0 />
      //Disable Modal button if no active wallet
      <div className=Css.(style([display(`flex)]))>
        <Button label="Cancel" style=Button.Gray onClick={_ => onClose()} />
        <Spacer width=1. />
        <Button label="Send" style=Button.Green type_="submit" />
      </div>
    </form>;
  };
};

[@react.component]
let make = (~onClose) => {
  <Modal title="Send Coda" onRequestClose={_ => onClose()}>
    <SendPaymentMutation>
      {(mutation, _) =>
         <SendForm
           onClose
           onSubmit={(
             {from, to_, amountFormatted, feeFormatted, memoOpt}: ModalState.Validated.t,
             afterSubmit,
           ) => {
             let variables =
               SendPayment.make(
                 ~from=Apollo.Encoders.publicKey(from),
                 ~to_=Apollo.Encoders.publicKey(to_),
                 ~amount=Apollo.Encoders.currency(amountFormatted),
                 ~fee=Apollo.Encoders.currency(feeFormatted),
                 ~memo=?memoOpt,
                 (),
               )##variables;
             let performMutation =
               Task.liftPromise(() =>
                 mutation(~variables, ~refetchQueries=[|"transactions"|], ())
               );
             Task.perform(
               performMutation,
               ~f=
                 fun
                 | Data(_)
                 | EmptyResponse => afterSubmit(Belt.Result.Ok())
                 | Errors(err) => {
                     /* TODO: Display more than first error? */
                     let message =
                       err
                       |> Array.get(~index=0)
                       |> Option.map(~f=(e: ReasonApolloTypes.graphqlError) =>
                            e.message
                          )
                       |> Option.withDefault(~default="Server error");
                     afterSubmit(Error(message));
                   },
             );
           }}
         />}
    </SendPaymentMutation>
  </Modal>;
};
