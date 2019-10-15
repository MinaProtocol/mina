open Tc;

module Styles = {
  open Css;

  let container = style([width(`percent(100.)), overflow(`hidden)]);
};

module Wallets = [%graphql
  {|
    query getWallets {
      ownedWallets {
        publicKey @bsDecoder(fn: "Apollo.Decoders.publicKey")
      }
    }
  |}
];

module WalletQuery = ReasonApollo.CreateQuery(Wallets);

[@react.component]
let make = () => {
  let url = ReasonReactRouter.useUrl();
  <div className=Styles.container>
    {switch (url.path) {
     | ["settings"] => <SettingsPage />
     | ["settings", publicKey] =>
       <AccountSettings publicKey={PublicKey.uriDecode(publicKey)} />
     | ["wallet", _pk, ..._] => <Transactions />
     | _ =>
       <WalletQuery>
         (
           ({result}) =>
             switch (result) {
             | Loading
             | Error(_) => <Transactions />
             | Data(data) =>
               data##ownedWallets
               |> Array.get(~index=0)
               |> Option.map(~f=w => w##publicKey)
               |> Option.iter(~f=pk =>
                    ReasonReact.Router.push(
                      "/wallet/" ++ PublicKey.uriEncode(pk),
                    )
                  );
               <Transactions />;
             }
         )
       </WalletQuery>
     }}
  </div>;
};
