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

  let textBox =
    style([
      width(`rem(21.)),
      selector("input", [maxWidth(`rem(12.0))]),
    ]);

  let fields = style([marginLeft(`rem(3.0))]);

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
      justifyContent(`flexStart),
    ]);

  let delegating = style([display(`flex), flexDirection(`column)]);

  let delegationProgressLabel =
    merge([
      Theme.Text.Body.regularLight,
      style([
        color(Theme.Colors.slate),
        display(`block),
        marginLeft(`rem(19.)),
        minWidth(`rem(20.)),
      ]),
    ]);

  let delegatingLabel =
    merge([
      Theme.Text.Body.regular,
      style([
        color(Theme.Colors.midnightBlue),
        display(`block),
        marginLeft(`rem(19.)),
      ]),
    ]);

  let breadcrumbText =
    merge([
      Theme.Text.Body.semiBold,
      style([color(Theme.Colors.hyperlink), marginBottom(`rem(0.5))]),
    ]);

  let keys =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      alignItems(`center),
    ]);
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
      <div className=Styles.fields>
        <Button
          style=Button.Red
          onClick={_ =>
            updateModal(x => Option.or_(Some({text: "", error: None}), x))
          }
          label="Delete account"
        />
      </div>
      {switch (modalState) {
       | None => React.null
       | Some({text, error}) =>
         <Modal
           title="Delete Account" onRequestClose={_ => updateModal(_ => None)}>
           <div className=Styles.modalContainer>
             <div className=Styles.deleteAlert>
               <Alert kind=`Warning defaultMessage=warningMessage />
             </div>
             {switch (error) {
              | Some(errorText) =>
                <Alert kind=`Danger defaultMessage=errorText />
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
                                   |> Option.map(
                                        ~f=(e: ReasonApolloTypes.graphqlError) =>
                                        e.message
                                      )
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
     pooledUserCommands(publicKey: $publicKey) {
        isDelegation
    }
     syncStatus
  }
|}
];

module AccountInfoQuery = ReasonApollo.CreateQuery(AccountInfo);

module DisableStaking = [%graphql
  {|
    mutation disableStaking {
      setStaking(input: {publicKeys: []}) {
        lastStaking
      }
    }
  |}
];
module DisableStakingMutation = ReasonApollo.CreateMutation(DisableStaking);

module BlockRewards = {
  [@react.component]
  let make = (~publicKey) => {
    let (stakingHovered, setStakingHovered) = React.useState(() => false);
    let (delegateHovered, setDelegateHovered) = React.useState(() => false);

    let accountInfoVariables =
      AccountInfo.make(~publicKey=Apollo.Encoders.publicKey(publicKey), ())##variables;
    <div>
      <h3 className=Theme.Text.Header.h3>
        {React.string("Block Rewards")}
      </h3>
      <Spacer height=1. />
      <AccountInfoQuery variables=accountInfoVariables>
        {response =>
           switch (response.result) {
           | Loading => <Loader />
           | Error((err: ReasonApolloTypes.apolloError)) =>
             <span> {React.string(err.message)} </span>
           | Data(data) =>
             let account = Option.getExn(data##account);
             let isDelegationInProgress =
               Array.any(
                 ~f=commands => commands##isDelegation,
                 data##pooledUserCommands |> Array.map(~f=(`UserCommand x) => x),
               );
             switch (account.delegateAccount, data##syncStatus) {
             | (None, `SYNCED) =>
               <Well>
                 <Alert
                   kind=`Warning
                   defaultMessage="Your node is synced, but the account has not entered the ledger yet because there are no funds in this account. Have you requested from the faucet yet?"
                 />
               </Well>
             | (None, _) =>
               <Well>
                 <Alert
                   kind=`Warning
                   defaultMessage="Wait until fully synced..."
                 />
               </Well>
             | (Some(delegate), _) =>
               let isDelegation =
                 isDelegationInProgress || delegate##publicKey != publicKey;

               <div>
                 <Well>
                   <div className=Styles.delegating>
                     <div
                       className=Css.(
                         style([display(`flex), justifyContent(`flexStart)])
                       )>
                       {account.stakingActive
                          ? <DisableStakingMutation>
                              (
                                (mutate, _) =>
                                  <Button
                                    width=12.
                                    height=2.5
                                    label={
                                            if (stakingHovered) {
                                              "Disable Staking"
                                            } else {
                                              "Staking Enabled"
                                            }
                                          }
                                    style={
                                            if (stakingHovered) {Button.Red} else {
                                              Button.Green
                                            }
                                          }
                                    onMouseEnter={_ =>
                                      setStakingHovered(_ => true)
                                    }
                                    onMouseLeave={_ =>
                                      setStakingHovered(_ => false)
                                    }
                                    onClick={_ =>
                                      Task.liftPromise(mutate)
                                      |> Task.perform(~f=_ =>
                                           {
                                             Bindings.setTimeout(100) |> ignore;
                                             response.refetch(
                                               Some(accountInfoVariables),
                                             );
                                           }
                                           |> ignore
                                         )
                                    }
                                  />
                              )
                            </DisableStakingMutation>
                          : <Button
                              width=12.
                              height=2.5
                              style=Button.HyperlinkBlue
                              label="Stake"
                              onClick={_ =>
                                ReasonReact.Router.push(
                                  "/settings/"
                                  ++ PublicKey.uriEncode(publicKey)
                                  ++ "/stake",
                                )
                              }
                            />}
                       <Spacer width=1. />
                       <img
                         src="https://cdn.discordapp.com/attachments/638495089232183306/641796805314478092/OR.png"
                         height="40px"
                       />
                       <Spacer width=1. />
                       <Button
                         width=12.
                         height=2.5
                         style={
                           isDelegation ? Button.Green : Button.HyperlinkBlue
                         }
                         label={
                                 if (delegateHovered && !isDelegation) {
                                   "Delegate";
                                 } else if (delegateHovered) {
                                   "Change Delegation";
                                 } else if (isDelegationInProgress) {
                                   "Delegation In Progress";
                                 } else if (isDelegation) {
                                   "Delegation Enabled";
                                 } else {
                                   "Delegate";
                                 }
                               }
                         onMouseEnter={_ => setDelegateHovered(_ => true)}
                         onMouseLeave={_ => setDelegateHovered(_ => false)}
                         onClick={_ =>
                           ReasonReact.Router.push(
                             "/settings/"
                             ++ PublicKey.uriEncode(publicKey)
                             ++ "/delegate",
                           )
                         }
                       />
                     </div>
                   </div>
                 </Well>
                 <Spacer height=0.5 />
                 {isDelegation
                    ? <p className=Styles.delegationProgressLabel>
                        {React.string(
                           "Delegation takes 24-36 hours to process.",
                         )}
                      </p>
                    : React.null}
                 <Spacer height=0.5 />
                 {if (delegate##publicKey == publicKey) {
                    React.null;
                  } else {
                    <span className=Styles.delegatingLabel>
                      {React.string("Delegating to: ")}
                      <AccountName pubkey=delegate##publicKey />
                    </span>;
                  }}
               </div>;
             };
           }}
      </AccountInfoQuery>
    </div>;
  };
};

[@bs.scope "window"] [@bs.val]
external showItemInFolder: string => unit = "showItemInFolder";

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
      <a
        className=Styles.breadcrumbText
        onClick={_ => ReasonReact.Router.push("/settings")}>
        {React.string("Global Settings >")}
      </a>
      <Spacer width=0.2 />
      <AccountName pubkey=publicKey className=Styles.breadcrumbText />
    </div>
    <Spacer height=1. />
    <h3 className=Theme.Text.Header.h3> {React.string("Account Basics")} </h3>
    <Spacer height=0.7 />
    <div className=Styles.fields>
      <div className=Styles.label> {React.string("Name")} </div>
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
            <TextField.Button
              text="Copy"
              color=`Blue
              onClick=handleClipboard
            />
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
    </div>
    <Spacer height=4.0 />
    <DeleteButton publicKey />
  </div>;
};
