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
  let activeWallet = Hooks.useActiveWallet();
  <>
    <Button
      label="Send"
      onClick={_ => setModalOpen(_ => true)}
      disabled={!Option.isSome(activeWallet)}
    />
    {switch (activeWallet) {
     | None => React.null
     | Some(pubkey) =>
       let walletQuery =
         WalletLocked.make(~publicKey=Apollo.Encoders.publicKey(pubkey), ());
       <WalletQuery variables=walletQuery##variables>
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
                       wallet=pubkey
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
