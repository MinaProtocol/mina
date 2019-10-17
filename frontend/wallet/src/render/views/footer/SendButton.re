open Tc;

// Only use the getExn on ownedWallets
module WalletLocked = [%graphql
  {|
    query walletLocked ($publicKey: PublicKey!) @bsRecord {
      wallet(publicKey: $publicKey) {
        locked @bsDecoder(fn: "Tc.Option.getExn")
      }
    }
  |}
];

module WalletQuery = ReasonApollo.CreateQuery(WalletLocked);

[@react.component]
let make = () => {
  let (modalOpen, setModalOpen) = React.useState(() => false);
  let activeAccount = Hooks.useActiveAccount();
  <>
    <Button
      label="Send"
      onClick={_ => setModalOpen(_ => true)}
      disabled={!Option.isSome(activeAccount)}
    />
    {switch (activeAccount) {
     | None => React.null
     | Some(pubkey) =>
       let accountQuery =
         WalletLocked.make(~publicKey=Apollo.Encoders.publicKey(pubkey), ());
       <WalletQuery variables=accountQuery##variables>
         (
           response =>
             switch (response.result) {
             | Loading
             | Error(_) => React.null
             | Data(data) =>
               switch (modalOpen, data##wallet) {
               | (false, _)
               | (true, None) => React.null
               | (true, Some(wallet)) =>
                 wallet##locked
                   ? <UnlockModal
                       account=pubkey
                       onClose={() => setModalOpen(_ => false)}
                       onSuccess={() => ()}
                     />
                   : <SendModal onClose={() => setModalOpen(_ => false)} />
               }
             }
         )
       </WalletQuery>;
     }}
  </>;
};
