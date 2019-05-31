let component = ReasonReact.statelessComponent("Header");

module Styles = {
  open Css;
  open Theme;

  let header =
    merge([
      style([
        position(`fixed),
        top(`px(0)),
        left(`px(0)),
        right(`px(0)),
        height(Spacing.headerHeight),
        maxHeight(Spacing.headerHeight),
        minHeight(Spacing.headerHeight),
        display(`flex),
        alignItems(`center),
        justifyContent(`spaceBetween),
        color(black),
        fontFamily("IBM Plex Sans, Sans-Serif"),
        padding2(~v=`zero, ~h=Theme.Spacing.defaultSpacing),
        borderBottom(`px(1), `solid, Colors.borderColor),
        CssElectron.appRegion(`drag),
      ]),
      notText,
    ]);

  let logo =
    style([display(`flex), alignItems(`center), marginLeft(`px(4))]);

  let rightButtons =
    style([
      display(`flex),
      alignItems(`center),
      justifyContent(`spaceBetween),
    ]);

  let deactivatedSettings =
    merge([Link.Styles.link, style([padding(`rem(0.5))])]);

  let activatedSettings =
    merge([
      deactivatedSettings,
      style([
        color(Theme.Colors.hyperlinkAlpha(0.8)),
        backgroundColor(Theme.Colors.hyperlinkAlpha(0.15)),
        borderRadius(`px(6)),
      ]),
    ]);
};

module SyncStatus = [%graphql
  {|
subscription syncStatus {
  newSyncUpdate {
    status
    description
  }
}
|}
];

module SyncStatusSubscription = ReasonApollo.CreateSubscription(SyncStatus);

[@react.component]
let make = () => {
  let url = ReasonReact.Router.useUrl();
  let onSettingsPage =
    switch (url.path) {
    | ["settings", ..._] => true
    | _ => false
    };
  <header className=Styles.header>
    <div className=Styles.logo>
      <img src="CodaLogo.svg" alt="Coda logo" />
    </div>
    <div className=Styles.rightButtons>
      <SyncStatusSubscription>
        {response =>
           switch (response.result) {
           | Loading => <Alert kind=`Warning message="Syncing" />
           | Error(_) => <Alert kind=`Danger message="Error" />
           | Data(response) =>
             let update = response##newSyncUpdate;
             switch (update##status) {
             | `STALE => <Alert kind=`Warning message="Stale" />
             | `ERROR => <Alert kind=`Danger message="Unsynced" />
             | `SYNCED => <Alert kind=`Success message="Synced" />
             | `BOOTSTRAP => <Alert kind=`Warning message="Syncing" />
             };
           }}
      </SyncStatusSubscription>
      <Spacer width=1.5 />
      <a
        className={
          onSettingsPage
            ? Styles.activatedSettings : Styles.deactivatedSettings
        }
        onClick={_e =>
          onSettingsPage
            ? ReasonReact.Router.push("/")
            : ReasonReact.Router.push("/settings")
        }>
        <Icon kind=Icon.Settings />
        <Spacer width=0.25 />
        {React.string("Settings")}
      </a>
    </div>
  </header>;
};
