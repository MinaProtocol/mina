open Tc;

module Styles = {
  open Css;

  let label =
    merge([
      Theme.Text.Body.semiBold,
      style([color(Theme.Colors.midnight), marginBottom(`rem(0.25))]),
    ]);
};

type modalState =
  | Delegate(option(PublicKey.t), option(Int64.t))
  | Stake(option(Int64.t));

let intForState = state =>
  switch (state) {
  | Delegate(_, _) => 0
  | Stake(_) => 1
  };

module ConsensusModal = {
  [@react.component]
  let make = (~state, ~updateModal) =>
    <Modal
      title="Change consensus" onRequestClose={_ => updateModal(_ => None)}>
      <Spacer height=0.5 />
      <ToggleButton
        options=[|"Delegate", "Stake"|]
        selected={intForState(state)}
        onChange={value =>
          updateModal(_ =>
            switch (value) {
            | 0 => Some(Delegate(None, None))
            | 1 => Some(Stake(None))
            | _ => None
            }
          )
        }
      />
      <Spacer height=1.5 />
      {switch (state) {
       | Delegate(pubkey, fee) =>
         <>
           <div>
             <div className=Styles.label> {React.string("Delegate to")} </div>
             <TextField
               label="Key"
               value={
                 Option.map(~f=PublicKey.toString, pubkey)
                 |> Option.withDefault(~default="")
               }
               mono=true
               onChange={value =>
                 updateModal(_ =>
                   Some(Delegate(Some(PublicKey.ofStringExn(value)), fee))
                 )
               }
             />
           </div>
           <Spacer height=1. />
           <div>
             <div className=Styles.label>
               {React.string("Transaction fee")}
             </div>
             <TextField.Currency
               label="Fee"
               value={
                 Option.map(~f=Int64.to_string, fee)
                 |> Option.withDefault(~default="")
               }
               placeholder="0"
               onChange={value => {
                 let serializedValue =
                   switch (value) {
                   | "" => None
                   | nonEmpty => Some(Int64.of_string(nonEmpty))
                   };
                 updateModal(_ => Some(Delegate(pubkey, serializedValue)));
               }}
             />
           </div>
         </>
       | Stake(fee) =>
         <>
           <TextField.Currency
             label="Fee"
             value={
               Option.map(~f=Int64.to_string, fee)
               |> Option.withDefault(~default="")
             }
             placeholder="0"
             onChange={value => {
               let serializedValue =
                 switch (value) {
                 | "" => None
                 | nonEmpty => Some(Int64.of_string(nonEmpty))
                 };
               updateModal(_ => Some(Stake(serializedValue)));
             }}
           />
           <Spacer height=1.5 />
           <Alert
             kind=`Warning
             message="In order to recieve your staking reward, your computer must be on and running this wallet application."
           />
         </>
       }}
      <Spacer height=1.5 />
      <div className=Css.(style([display(`flex)]))>
        <Button
          label="Cancel"
          style=Button.Gray
          onClick={_ => updateModal(_ => None)}
        />
        <Spacer width=1. />
        <Button label="Save" style=Button.Green />
      </div>
    </Modal>;
};

[@react.component]
let make = () => {
  let (modalState, updateModal) = React.useState(() => None);
  <div>
    <h3 className=Theme.Text.Header.h3>
      {React.string("Consensus Settings")}
    </h3>
    <Spacer height=0.5 />
    <Well>
      <div className=Css.(style([display(`flex), alignItems(`flexEnd)]))>
        <div className=Css.(style([flexGrow(1.)]))>
          <div className=Styles.label> {React.string("Delegating to")} </div>
          <TextField
            label="Key"
            value=""
            mono=true
            onChange={_ => ()}
            disabled=true
          />
        </div>
        <Spacer width=1. />
        <Button
          width=8.
          height=2.5
          style=Button.Green
          label="Change"
          onClick={_ => updateModal(_ => Some(Delegate(None, None)))}
        />
      </div>
    </Well>
    {switch (modalState) {
     | None => React.null
     | Some(state) => <ConsensusModal state updateModal />
     }}
  </div>;
};
