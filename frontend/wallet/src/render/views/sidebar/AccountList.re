open Tc;

module Styles = {
  open Css;

  let container =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`flexStart),
      width(`percent(100.)),
      height(`auto),
      overflowY(`auto),
      paddingBottom(`rem(2.)),
    ]);
};

type ownedAccounts =
  Account.t = {
    locked: option(bool),
    publicKey: PublicKey.t,
    balance: {. "total": int64},
  };

module Accounts = [%graphql
  {| query getWallets { ownedWallets @bsRecord {
      publicKey @bsDecoder(fn: "Apollo.Decoders.publicKey")
      locked
      balance {
          total @bsDecoder(fn: "Apollo.Decoders.int64")
      }
    }} |}
];
module AccountQuery = ReasonApollo.CreateQuery(Accounts);
[@react.component]
let make = () => {
  <AccountQuery partialRefetch=true>
    {response =>
       switch (response.result) {
       | Loading => <Loader.Page> <Loader /> </Loader.Page>
       | Error(err) => React.string(err##message)
       | Data(accounts) =>
         <BlockListener
           refetch={() => response.refetch(None)}
           subscribeToMore={response.subscribeToMore}>
           <div className=Styles.container>
             {React.array(
                Array.map(
                  ~f=
                    account =>
                      <AccountItem
                        key={PublicKey.toString(account.publicKey)}
                        account
                      />,
                  accounts##ownedWallets,
                ),
              )}
           </div>
         </BlockListener>
       }}
  </AccountQuery>;
};
