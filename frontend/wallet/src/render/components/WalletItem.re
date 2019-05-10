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
      color(grey),
      padding2(~v=`px(0), ~h=Theme.Spacing.defaultSpacing),
    ]);

  let inactiveWalletItem =
    merge([walletItem, style([hover([color(Colors.saville)])]), notText]);

  let activeWalletItem =
    merge([
      walletItem,
      style([
        color(Colors.saville),
        backgroundColor(Colors.hyperlinkAlpha(0.15)),
      ]),
      notText,
    ]);

  let walletName = style([fontWeight(`num(500)), fontSize(`px(16))]);

  let balance =
    style([
      fontWeight(`num(300)),
      marginTop(`em(0.25)),
      fontSize(`px(19)),
      height(`em(1.5)),
    ]);
};

[@react.component]
let make = (~wallet: Wallet.t) => {
  let (settings, _setSettings) = React.useContext(SettingsProvider.context);
  let (activeWallet, setActiveWallet) =
    React.useContext(ActiveWalletProvider.context);

  let isActive =
    Option.withDefault(
      ~default=false,
      Option.map(~f=active => active == wallet.key, activeWallet),
    );

  let walletName =
    Option.withDefault(
      ~default=PublicKey.toString(wallet.key),
      Option.andThen(~f=s => SettingsRenderer.lookup(s, wallet.key), settings),
    );

  <div
    className={
      switch (isActive) {
      | false => Styles.inactiveWalletItem
      | true => Styles.activeWalletItem
      }
    }
    onClick={_ => setActiveWallet(wallet.key)}>
    <div className=Styles.walletName>
      {ReasonReact.string(walletName)}
    </div>
    <div className=Styles.balance>
      {ReasonReact.string({js|■ |js} ++ wallet.balance)}
    </div>
  </div>;
};
