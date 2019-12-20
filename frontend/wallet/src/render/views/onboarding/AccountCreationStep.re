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

module Styles = {
  open Css;

  let hero = {
    style([display(`flex), flexDirection(`row)]);
  };

  let fadeIn =
    keyframes([
      (0, [opacity(0.), top(`px(50))]),
      (100, [opacity(1.), top(`px(0))]),
    ]);

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
  let header = {
    merge([
      Theme.Text.Header.h1,
      style([animation(fadeIn, ~duration=500, ~iterationCount=`count(1))]),
    ]);
  };
  let heroBody = {
    merge([
      Theme.Text.Body.regularLight,
      style([
        opacity(0.),
        maxWidth(`rem(21.5)),
        color(Theme.Colors.midnightBlue),
        animation(fadeIn, ~duration=500, ~iterationCount=`count(1)),
        animationDelay(250),
        animationFillMode(`forwards),
      ]),
    ]);
  };
  let buttonRow = {
    style([display(`flex), flexDirection(`row)]);
  };
  let textFields = {
    style([
      opacity(0.),
      animation(fadeIn, ~duration=500, ~iterationCount=`count(1)),
      animationDelay(500),
      animationFillMode(`forwards),
    ]);
  };
};

[@react.component]
let make = (~nextStep, ~prevStep) => {
  let (accountName, setName) = React.useState(() => defaultName);
  let (password, setPassword) = React.useState(() => "");

  let (_settings, updateAddressBook) =
    React.useContext(AddressBookProvider.context);

  let mutationVariables = AddAccount.make(~password, ())##variables;

  <div className=Theme.Onboarding.main>
    <div className=Styles.hero>
      <div className=Styles.heroLeft>
        <FadeIn duration=500>
          <h1 className=Styles.header>
            {React.string("Create Your Account")}
          </h1>
        </FadeIn>
        <Spacer height=0.5 />
        <FadeIn duration=500 delay=150>
          <p className=Styles.heroBody>
            {React.string(
               "Create your first account to complete setting up Coda Wallet. Please be sure to choose a secure password.",
             )}
          </p>
        </FadeIn>
        <FadeIn duration=500 delay=200>
          <div className=Styles.textFields>
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
          </div>
        </FadeIn>
        <div className=Styles.buttonRow>
          <Button
            style=Button.Gray
            label="Go Back"
            onClick={_ => prevStep()}
          />
          <Spacer width=0.5 />
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
      </div>
    </div>
  </div>;
};
