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
      borderBottom(`px(1), `solid, Theme.Colors.borderColor),
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

  let walletName = Text.body;

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
  let (settings, _setSettings) = React.useContext(SettingsProvider.context);
  let (activeWallet, setActiveWallet) =
    React.useContext(ActiveWalletProvider.context);

  let isActive =
    Option.withDefault(
      ~default=false,
      Option.map(~f=active => active == wallet.key, activeWallet),
    );

  let walletName = SettingsRenderer.getWalletName(settings, wallet.key);

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
