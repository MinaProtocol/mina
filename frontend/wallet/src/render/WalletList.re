open Tc;

module GetWallets = [%graphql
  {|
query getWallets {
  wallets {
    publicKey
      balance { total }
  }
} |}
];
module GetWalletsQuery = ReasonApollo.CreateQuery(GetWallets);

module AddWallet = [%graphql
  {|
    mutation addAWallet {
      addWallet(input: {}) {
        publicKey
      }
    }
  |}
];
module AddWalletMutation = ReasonApollo.CreateMutation(AddWallet);

[@react.component]
let make = (~settings, ~setSettingsOrError) => {
  <div>
    <GetWalletsQuery>
      ...{({result}) => {
        Js.log2("Result of query: ", result);
        switch (result) {
        | Loading => <div> {ReasonReact.string("Loading")} </div>
        | Error(error) => <div> {ReasonReact.string(error##message)} </div>
        | Data(response) =>
          response##wallets
          |> Array.map(~f=data => Wallet.ofGraphqlExn(data))
          |> Array.map(~f=wallet =>
               <WalletItem
                 key={wallet.Wallet.key |> PublicKey.toString}
                 wallet
                 settings
                 setSettingsOrError
               />
             )
          |> ReasonReact.array
        };
      }}
    </GetWalletsQuery>
    <AddWalletMutation>
      ...{(mutation, result) => {
        Js.log2("Response in mutation", result);
        <div>
          <button
            onClick={_mouseEvent =>
              mutation(~refetchQueries=[|"getWallets"|], ()) |> ignore
            }>
            {ReasonReact.string("+ Add Wallet")}
          </button>
        </div>;
      }}
    </AddWalletMutation>
  </div>;
};
