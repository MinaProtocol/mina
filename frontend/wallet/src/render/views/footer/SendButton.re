open Tc;

// Only use the getExn on ownedWallets
module AccountLocked = [%graphql
  {|
    query walletLocked ($publicKey: PublicKey!) @bsRecord {
      wallet(publicKey: $publicKey) {
        locked @bsDecoder(fn: "Tc.Option.getExn")
      }
    }
  |}
];

module AccountQuery = ReasonApollo.CreateQuery(AccountLocked);

[@react.component]
let make = () => {
  let (modalOpen, setModalOpen) = React.useState(() => false);
  let activeAccount = Hooks.useActiveAccount();
  <>
    <Button
      label="send"
      onClick={_ => setModalOpen(_ => true)}
      disabled={!Option.isSome(activeAccount)}
    />
    {switch (activeAccount) {
     | None => React.null
     | Some(pubkey) =>
       let accountQuery =
         AccountLocked.make(
           ~publicKey=Apollo.Encoders.publicKey(pubkey),
           (),
         );
       <AccountQuery variables=accountQuery##variables>
         (
           response =>
             switch (response.result) {
             | Loading
             | Error(_) => React.null
             | Data(data) =>
               switch (modalOpen, data##wallet) {
               | (false, _)
               | (true, None) => React.null
               | (true, Some(account)) =>
                 account##locked
                   ? <UnlockModal
                       account=pubkey
                       onClose={() => setModalOpen(_ => false)}
                       onSuccess={() => ()}
                     />
                   : <SendModal onClose={() => setModalOpen(_ => false)} />
               }
             }
         )
       </AccountQuery>;
     }}
  </>;
};