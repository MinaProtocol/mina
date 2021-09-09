open Tc;

module Styles = {
  open Css;

  let container = style([width(`percent(100.)), overflow(`hidden)]);
};

module Accounts = [%graphql
  {|
    query getWallets {
      ownedWallets{
        publicKey @bsDecoder(fn: "Apollo.Decoders.publicKey")
      }
    }
  |}
];

module AccountQuery = ReasonApollo.CreateQuery(Accounts);

[@react.component]
let make = () => {
  let url = ReasonReactRouter.useUrl();
  <div className=Styles.container>
    {switch (url.path) {
     | ["settings"] => <SettingsPage />
     | ["settings", publicKey] =>
       <AccountSettings publicKey={PublicKey.uriDecode(publicKey)} />
     | ["settings", publicKey, "delegate"] =>
       <DelegationSettings publicKey={PublicKey.uriDecode(publicKey)} />
     | ["settings", publicKey, "stake"] =>
       <StakingSettings publicKey={PublicKey.uriDecode(publicKey)} />
     | ["account", _pk, ..._] => <Transactions />
     | _ =>
       <AccountQuery>
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
                      "/account/" ++ PublicKey.uriEncode(pk),
                    )
                  );
               <Transactions />;
             }
         )
       </AccountQuery>
     }}
  </div>;
};
