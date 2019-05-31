open Tc;

module Styles = {
  open Css;

  let container =
    style([
      height(`percent(100.)),
      padding(`rem(2.)),
      backgroundColor(Theme.Colors.greyish(0.1)),
    ]);

  let walletItemContainer =
    style([
      display(`flex),
      flexDirection(`column),
      backgroundColor(white),
      padding(`rem(0.5)),
      borderRadius(`px(6)),
      border(`px(1), `solid, Theme.Colors.slateAlpha(0.5)),
      width(`rem(28.)),
    ]);

  let walletItem =
    merge([
      Theme.Text.Body.regular,
      style([
        margin(`rem(0.5)),
        color(Theme.Colors.midnight),
        display(`flex),
        alignItems(`center),
      ]),
    ]);

  let walletName = style([width(`rem(12.5))]);

  let walletChevron = style([color(Theme.Colors.teal)]);

  let line =
    style([
      border(`zero, `none, transparent),
      borderTop(`px(1), `solid, Theme.Colors.slateAlpha(0.5)),
      width(`percent(100.)),
    ]);
};

module SettingsQueryString = [%graphql
  {| query getSettings {
      version
      ownedWallets {
        publicKey @bsDecoder(fn: "Apollo.Decoders.publicKey")
      }
     }
|}
];

module SettingsQuery = ReasonApollo.CreateQuery(SettingsQueryString);

module WalletItem = {
  [@react.component]
  let make = (~publicKey) => {
    let (addressBook, _) = React.useContext(AddressBookProvider.context);
    let keyStr = PublicKey.toString(publicKey);
    let route = "/settings/" ++ Js.Global.encodeURIComponent(keyStr);
    <div
      className=Styles.walletItem
      onClick={_ => ReasonReact.Router.push(route)}>
      <div className=Styles.walletName>
        {React.string(AddressBook.getWalletName(addressBook, publicKey))}
      </div>
      <Pill> {React.string(PublicKey.prettyPrint(publicKey))} </Pill>
      <Spacer width=5.0 />
      <span className=Styles.walletChevron>
        <Icon kind=Icon.EmptyChevronRight />
      </span>
    </div>;
  };
};

[@react.component]
let make = () => {
  <div className=Styles.container>
    <span className=Theme.Text.title> {React.string("Settings")} </span>
    <Spacer height=1. />
    <SettingsQuery>
      {response =>
         switch (response.result) {
         | Loading => React.string("...")
         | Error(err) => React.string(err##message)
         | Data(data) =>
           <>
             <span className=Theme.Text.Body.regular>
               {React.string("Wallet version: " ++ data##version)}
             </span>
             <div className=Styles.walletItemContainer>
               {data##ownedWallets
                |> Array.mapi(~f=(i, w) =>
                     <>
                       <WalletItem
                         key={PublicKey.toString(w##publicKey)}
                         publicKey=w##publicKey
                       />
                       {i < Array.length(data##ownedWallets) - 1
                          ? <hr className=Styles.line /> : React.null}
                     </>
                   )
                |> React.array}
             </div>
           </>
         }}
    </SettingsQuery>
  </div>;
};
