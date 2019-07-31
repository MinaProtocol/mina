open Tc;

module Styles = {
  open Css;
  open Theme;

  let walletItem =
    style([
      flexShrink(0),
      display(`flex),
      flexDirection(`column),
      alignItems(`flexStart),
      justifyContent(`center),
      height(`rem(4.5)),
      fontFamily("IBM Plex Sans, Sans-Serif"),
      color(Theme.Colors.slateAlpha(0.5)),
      padding2(~v=`px(0), ~h=`rem(1.25)),
      borderBottom(`px(1), `solid, Theme.Colors.borderColor),
      borderTop(`px(1), `solid, white),
    ]);

  let inactiveWalletItem =
    merge([walletItem, style([hover([color(Colors.saville)])]), notText]);

  let activeWalletItem =
    merge([
      walletItem,
      style([
        color(Colors.marine),
        backgroundColor(Colors.hyperlinkAlpha(0.15)),
      ]),
      notText,
    ]);

  let balance =
    style([
      fontWeight(`num(500)),
      marginTop(`rem(0.25)),
      fontSize(`rem(1.25)),
      height(`rem(1.5)),
      marginBottom(`rem(0.25)),
    ]);
};

[@react.component]
let make = (~wallet: Wallet.t) => {
  let isActive =
    Option.map(Hooks.useActiveWallet(), ~f=activeWallet =>
      PublicKey.equal(activeWallet, wallet.publicKey)
    )
    |> Option.withDefault(~default=false);

  <div
    className={
      switch (isActive) {
      | false => Styles.inactiveWalletItem
      | true => Styles.activeWalletItem
      }
    }
    onClick={_ =>
      ReasonReact.Router.push(
        "/wallet/" ++ PublicKey.uriEncode(wallet.publicKey),
      )
    }>
    <WalletName pubkey={wallet.publicKey} />
    <div className=Styles.balance>
      {ReasonReact.string(
         {js|■ |js} ++ Int64.to_string(wallet.balance##total),
       )}
    </div>
  </div>;
};
