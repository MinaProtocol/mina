let defaultName = "Primary Account";

module AddAccount = [%graphql
  {|
     mutation addWallet($password: String!) {
         addWallet(input: {password: $password}) {
           publicKey @bsDecoder(fn: "Apollo.Decoders.publicKey")
         }
     }
   |}
];

module AddAccountMutation = ReasonApollo.CreateMutation(AddAccount);

[@react.component]
let make = (~nextStep, ~prevStep) => {
  let (accountName, setName) = React.useState(() => defaultName);
  let (password, setPassword) = React.useState(() => "");

  let (_settings, updateAddressBook) =
    React.useContext(AddressBookProvider.context);

  let mutationVariables = AddAccount.make(~password, ())##variables;

  <OnboardingTemplate
    heading="Credential Setup"
    description={
      <p>
        {React.string("Please enter an account name and a secure password.")}
      </p>
    }
    miscLeft=
      <>
        <FadeIn duration=500 delay=150>
          <Spacer height=0.5 />
          <TextField
            label="Name"
            onChange={value => setName(_ => value)}
            value=accountName
          />
          <Spacer height=0.5 />
          <TextField
            label="Password"
            type_="password"
            onChange={value => setPassword(_ => value)}
            value=password
          />
          <Spacer height=2. />
        </FadeIn>
        <div className=OnboardingTemplate.Styles.buttonRow>
          <Button
            style=Button.MidnightBlue
            label="Go Back"
            onClick={_ => prevStep()}
          />
          <Spacer width=1.5 />
          <AddAccountMutation>
            {(mutation, {result}) =>
               <>
                 <Button
                   label="Create"
                   style=Button.HyperlinkBlue
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
                      AddressBook.set(~key, ~name=accountName),
                    );
                    nextStep();
                    React.null;
                  | _ => React.null
                  }}
               </>}
          </AddAccountMutation>
        </div>
      </>
  />;
};
