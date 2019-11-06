open Tc;

module Styles = {
  open Css;

  let container = SettingsPage.Styles.container;

  let backHeader = style([display(`flex), alignItems(`center)]);

  let backIcon =
    style([
      display(`inlineFlex),
      color(Theme.Colors.hyperlink),
      hover([color(Theme.Colors.hyperlinkAlpha(0.5))]),
    ]);

  let backHeaderText =
    merge([Theme.Text.Header.h3, style([color(Theme.Colors.midnight)])]);

  let headerAccountName = style([fontSize(`rem(1.25))]);

  let label =
    merge([
      Theme.Text.Body.semiBold,
      style([color(Theme.Colors.midnight), marginBottom(`rem(0.25))]),
    ]);

  let deleteModalLabel = merge([label, style([alignSelf(`flexStart)])]);

  let deleteAlert = style([margin2(~v=`rem(0.5), ~h=`zero)]);

  let textBox = style([width(`rem(21.))]);

  let modalContainer =
    style([
      width(`rem(22.)),
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
      margin(`auto),
    ]);

  let buttonWrapper = style([display(`flex)]);

  let blockRewards =
    style([
      display(`flex),
      flexDirection(`row),
      alignItems(`center),
      justifyContent(`spaceBetween),
    ]);

  let delegating = style([display(`flex), flexDirection(`column)]);
};

module DeleteAccount = [%graphql
  {|
    mutation deleteWallet($key: PublicKey!) {
      deleteWallet(input: {publicKey: $key}) {
        publicKey
      }
    }
  |}
];

module DeleteAccountMutation = ReasonApollo.CreateMutation(DeleteAccount);

module DeleteButton = {
  type modalState = {
    text: string,
    error: option(string),
  };
  [@react.component]
  let make = (~publicKey) => {
    let (modalState, updateModal) = React.useState(() => None);
    let (addressBook, _) = React.useContext(AddressBookProvider.context);
    let accountName =
      switch (AddressBook.lookup(addressBook, publicKey)) {
      | Some(name) => name
      | None =>
        PublicKey.toString(publicKey) |> String.slice(~from=0, ~to_=5)
      };
    let warningMessage =
      "Are you sure you want to delete "
      ++ accountName
      ++ "? \
      This can't be undone, and you may lose the funds in this account.";
    <>
      <h3 className=Theme.Text.Header.h3>
        {React.string("Account Removal")}
      </h3>
      <Spacer height=1. />
      <Button
        style=Button.Red
        onClick={_ =>
          updateModal(x => Option.or_(Some({text: "", error: None}), x))
        }
        label="Delete account"
      />
      {switch (modalState) {
       | None => React.null
       | Some({text, error}) =>
         <Modal
           title="Delete Account" onRequestClose={_ => updateModal(_ => None)}>
           <div className=Styles.modalContainer>
             <div className=Styles.deleteAlert>
               <Alert kind=`Warning message=warningMessage />
             </div>
             {switch (error) {
              | Some(errorText) => <Alert kind=`Danger message=errorText />
              | None => React.null
              }}
             <div className=Styles.deleteModalLabel>
               {React.string("Type account name to confirm:")}
             </div>
             <TextField
               label="Name"
               value=text
               onChange={s => updateModal(_ => Some({text: s, error: None}))}
             />
             <Spacer height=2. />
             <div className=Styles.buttonWrapper>
               <Button
                 label="Cancel"
                 style=Button.Gray
                 onClick={_ => updateModal(_ => None)}
               />
               <Spacer width=1. />
               <DeleteAccountMutation>
                 (
                   (mutation, _) =>
                     <Button
                       label="Delete"
                       style=Button.Red
                       onClick={_ => {
                         let variables =
                           DeleteAccount.make(
                             ~key=Apollo.Encoders.publicKey(publicKey),
                             (),
                           )##variables;
                         let performMutation =
                           Task.liftErrorPromise(() =>
                             mutation(
                               ~variables,
                               ~refetchQueries=[|"getWallets"|],
                               (),
                             )
                           );
                         Task.attempt(
                           performMutation,
                           ~f=
                             fun
                             | Ok(Data(_))
                             | Ok(EmptyResponse) => {
                                 updateModal(_ => None);
                                 ReasonReact.Router.push("/settings");
                               }
                             | Ok(Errors(err)) => {
                                 let message =
                                   err
                                   |> Array.get(~index=0)
                                   |> Option.map(~f=e => e##message)
                                   |> Option.withDefault(
                                        ~default="Server error",
                                      );
                                 updateModal(_ =>
                                   Some({text, error: Some(message)})
                                 );
                               }
                             | Error(e) =>
                               updateModal(_ =>
                                 Some({
                                   text,
                                   error: Some(Js.String.make(e)),
                                 })
                               ),
                         );
                       }}
                       disabled={text != accountName}
                     />
                 )
               </DeleteAccountMutation>
             </div>
           </div>
         </Modal>
       }}
    </>;
  };
};

type accounts = {
  stakingActive: bool,
  publicKey: PublicKey.t,
  delegateAccount: option({. "publicKey": PublicKey.t}),
};

module AccountInfo = [%graphql
  {|
    query getAccountInfo ($publicKey: PublicKey!){
      account(publicKey: $publicKey) @bsRecord {
        stakingActive
        publicKey @bsDecoder(fn: "Apollo.Decoders.publicKey")
        delegateAccount {
           publicKey @bsDecoder(fn: "Apollo.Decoders.publicKey")
        }
    }
  }
|}
];
module AccountInfoQuery = ReasonApollo.CreateQuery(AccountInfo);

module StakingConfig = [%graphql
  {|
    mutation ($publicKey: [PublicKey!]!){
      setStaking(input: $publicKey) {
        lastStaking
      }
    }
  |}
];

module StakingMutation = ReasonApollo.CreateMutation(StakingConfig);

module StakingToggle = {
  [@react.component]
  let make = (~publicKey as _pubkey, ~active) => {
    <Toggle
      //    let variables =
      //      StakingConfig.make(
      //        ~publicKey=[|Apollo.Encoders.publicKey(publicKey)|],
      //        (),
      //      )##variables;
      //    <StakingMutation>
      //      {(mutation, _) =>
      value=active
      onChange={_ => ReasonReact.Router.push("/settings/:id/stake")}
    />;
  };
  //    </StakingMutation>;
  //  };
};

module BlockRewards = {
  [@react.component]
  let make = (~publicKey) => {
    let accountInfoVariables =
      AccountInfo.make(~publicKey=Apollo.Encoders.publicKey(publicKey), ())##variables;
    <div>
      <h3 className=Theme.Text.Header.h3>
        {React.string("Block Rewards")}
      </h3>
      <Spacer height=0.5 />
      <Well>
        <AccountInfoQuery variables=accountInfoVariables>
          {response =>
             switch (response.result) {
             | Loading => <Loader />
             | Error(err) => <span> {React.string(err##message)} </span>
             | Data(data) =>
               let account = Option.getExn(data##account);
               let delegate = Option.getExn(account.delegateAccount);
               delegate##publicKey == publicKey
                 ? <div className=Styles.blockRewards>
                     <div
                       className=Css.(
                         style([display(`flex), alignItems(`center)])
                       )>
                       <p className=Theme.Text.Body.regular>
                         {account.stakingActive
                            ? {
                              React.string("Staking is ON");
                            }
                            : {
                              React.string("Staking is OFF");
                            }}
                       </p>
                       <Spacer width=1. />
                       <StakingToggle
                         publicKey
                         active={account.stakingActive}
                       />
                     </div>
                     <Button
                       width=8.
                       height=2.5
                       style=Button.Green
                       label="Delegate"
                       onClick={_ =>
                         ReasonReact.Router.push(
                           "/settings/"
                           ++ PublicKey.uriEncode(publicKey)
                           ++ "/delegate",
                         )
                       }
                     />
                   </div>
                 : <div className=Styles.delegating>
                     <span className=Theme.Text.Body.regular>
                       {React.string("Delegating to: ")}
                       <AccountName pubkey=delegate##publicKey />
                     </span>
                     <Spacer height=1. />
                     <div className=Css.(style([display(`flex), justifyContent(`spaceBetween)]))>
                       <Button
                         width=12.
                         height=2.5
                         style=Button.Green
                         label="Change Delegation"
                         onClick={_ =>
                           ReasonReact.Router.push(
                             "/settings/"
                             ++ PublicKey.uriEncode(publicKey)
                             ++ "/delegate",
                           )
                         }
                       />
                       <Button
                         width=12.
                         height=2.5
                         style=Button.Gray
                         label="Stake"
                         onClick={_ =>
                           ReasonReact.Router.push("/settings/:id/stake")
                         }
                       />
                     </div>
                   </div>;
             }}
        </AccountInfoQuery>
      </Well>
    </div>;
  };
};

[@bs.scope "window"] [@bs.val] external showItemInFolder: string => unit = "";

module KeypathQueryString = [%graphql
  {|
    query ($publicKey: PublicKey!)  {
      wallet(publicKey: $publicKey) {
        privateKeyPath
      }
    }
  |}
];

module KeypathQuery = ReasonApollo.CreateQuery(KeypathQueryString);

[@react.component]
let make = (~publicKey) => {
  let (addressBook, updateAddressBook) =
    React.useContext(AddressBookProvider.context);

  let handleClipboard = () =>
    ignore(
      Bindings.Navigator.Clipboard.writeText(PublicKey.toString(publicKey)),
    );

  <div className=Styles.container>
    <div className=Styles.backHeader>
      <span
        className=Styles.backIcon
        onClick={_ => ReasonReact.Router.push("/settings")}>
        <Icon kind=Icon.BackArrow />
      </span>
      <Spacer width=0.5 />
      <span className=Styles.backHeaderText>
        <AccountName pubkey=publicKey className=Styles.headerAccountName />
        {React.string(" settings")}
      </span>
    </div>
    <Spacer height=1. />
    <div className=Styles.label> {React.string("Account name")} </div>
    <div className=Styles.textBox>
      <TextField
        label="Name"
        value={Option.withDefault(
          ~default="",
          AddressBook.lookup(addressBook, publicKey),
        )}
        placeholder="My Coda Account"
        onChange={value =>
          updateAddressBook(ab =>
            AddressBook.set(ab, ~key=publicKey, ~name=value)
          )
        }
      />
    </div>
    <Spacer height=1. />
    <div className=Styles.label> {React.string("Public key")} </div>
    <div className=Styles.textBox>
      <TextField
        label="Key"
        value={PublicKey.prettyPrint(publicKey)}
        mono=true
        onChange={_ => ()}
        button={
          <TextField.Button text="Copy" color=`Blue onClick=handleClipboard />
        }
      />
    </div>
    <Spacer height=1. />
    <div className=Styles.label> {React.string("Private key")} </div>
    <div className=Styles.textBox>
      <KeypathQuery
        variables=
          {KeypathQueryString.make(
             ~publicKey=Apollo.Encoders.publicKey(publicKey),
             (),
           )##variables}>
        {({result}) => {
           let path =
             switch (result) {
             | Loading
             | Error(_) => None
             | Data(data) =>
               Option.map(~f=w => w##privateKeyPath, data##wallet)
             };
           switch (path) {
           | Some(secretKeyPath) =>
             <TextField
               label="Path"
               value=secretKeyPath
               onChange=ignore
               button={
                 <TextField.Button
                   text="Open"
                   color=`Teal
                   onClick={_ => showItemInFolder(secretKeyPath)}
                 />
               }
             />
           | None =>
             <TextField
               label="Path"
               value=""
               onChange=ignore
               button={
                 <TextField.Button
                   text="Open"
                   disabled=true
                   color=`Teal
                   onClick=ignore
                 />
               }
             />
           };
         }}
      </KeypathQuery>
    </div>
    <Spacer height=1.5 />
    <BlockRewards publicKey />
    <Spacer height=1.5 />
    <DeleteButton publicKey />
  </div>;
};
