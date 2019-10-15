let defaultName = "Primary Account";

module AddWallet = [%graphql
  {|
     mutation addWallet($password: String!) {
         addWallet(input: {password: $password}) {
           publicKey @bsDecoder(fn: "Apollo.Decoders.publicKey")
         }
     }
   |}
];

module AddWalletMutation = ReasonApollo.CreateMutation(AddWallet);

module Styles = {
  open Css;

  let hero = {
    style([display(`flex), flexDirection(`row)]);
  };

  let heroLeft = {
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`center),
      width(`percent(100.0)),
      maxWidth(`rem(28.0)),
      marginLeft(`px(80)),
    ]);
  };

  let heroBody = {
    merge([
      Theme.Text.Body.regular,
      style([maxWidth(`rem(21.5)), color(Theme.Colors.midnightBlue)]),
    ]);
  };
  let buttonRow = {
    style([display(`flex), flexDirection(`row)]);
  };
};

[@react.component]
let make = (~nextStep, ~prevStep) => {
  let (walletName, setName) = React.useState(() => defaultName);
  let (password, setPassword) = React.useState(() => "");

  let (_settings, updateAddressBook) =
    React.useContext(AddressBookProvider.context);

  let mutationVariables = AddWallet.make(~password, ())##variables;

  <div className=Theme.Onboarding.main>
    <div className=Styles.hero>
      <div className=Styles.heroLeft>
        <h1 className=Theme.Text.Header.h1>
          {React.string("Create Your Account")}
        </h1>
        <Spacer height=1. />
        <p className=Styles.heroBody>
          {React.string(
             "Create your first account to complete setting up Coda Wallet. Please be sure to choose a secure password.",
           )}
        </p>
        <div>
          <Spacer height=1. />
          <TextField
            label="Name"
            onChange={value => setName(_ => value)}
            value=walletName
          />
          <Spacer height=0.5 />
          <TextField
            label="Password"
            type_="password"
            onChange={value => setPassword(_ => value)}
            value=password
          />
          <Spacer height=2. />
        </div>
        <div className=Styles.buttonRow>
          <Button
            style=Button.Gray
            label="Go Back"
            onClick={_ => prevStep()}
          />
          <Spacer width=0.5 />
          <AddWalletMutation>
            {(mutation, {result}) =>
               <>
                 <Button
                   label="Create"
                   disabled={
                     switch (result) {
                     | Loading => true
                     | _ => false
                     }
                   }
                   onClick={_ =>
                     mutation(
                       ~variables=mutationVariables,
                       ~refetchQueries=[|"getWallets"|],
                       (),
                     )
                     |> ignore
                   }
                 />
                 {switch (result) {
                  | Data(data) =>
                    let key = data##addWallet##publicKey;
                    updateAddressBook(
                      AddressBook.set(~key, ~name=walletName),
                    );
                    ReasonReact.Router.push(
                      "/wallet/" ++ PublicKey.uriEncode(key),
                    );
                    nextStep();
                    React.null;
                  | _ => React.null
                  }}
               </>}
          </AddWalletMutation>
        </div>
      </div>
      <div
        // Graphic goes here
      />
    </div>
  </div>;
};
