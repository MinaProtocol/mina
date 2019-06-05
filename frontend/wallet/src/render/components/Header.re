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
    merge([
      Link.Styles.link,
      style([
        padding4(
          ~top=`rem(0.5),
          ~right=`rem(0.75),
          ~bottom=`rem(0.5),
          ~left=`rem(0.5),
        ),
      ]),
    ]);

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

module SyncStatusQ = [%graphql
  {|
    query querySyncStatus {
      syncState {
        status
        description
      }
    }
  |}
];

module SyncStatusQuery = ReasonApollo.CreateQuery(SyncStatusQ);

module SyncStatus = {
  module SubscriptionGQL = [%graphql
    {|
    subscription syncStatus {
      newSyncUpdate {
        status
        description
      }
    }
    |}
  ];

  module Subscription = ReasonApollo.CreateSubscription(SubscriptionGQL);

  [@react.component]
  let make =
      (
        ~result,
        ~subscribeToMore:
           (
             ~document: ReasonApolloTypes.queryString,
             ~variables: Js.Json.t=?,
             ~updateQuery: ReasonApolloQuery.updateQuerySubscriptionT=?,
             ~onError: ReasonApolloQuery.onErrorT=?,
             unit
           ) =>
           unit,
      ) => {
    let _ =
      React.useEffect0(() => {
        subscribeToMore(~document=Subscription.graphQLSubscriptionAST, ());
        None;
      });
    switch ((result: SyncStatusQuery.response)) {
    | Loading => <Alert kind=`Warning message="Connecting" />
    | Error(_) => <Alert kind=`Danger message="Error" />
    | Data(response) =>
      let update = response##syncState;
      switch (update##status) {
      | `STALE => <Alert kind=`Warning message="Stale" />
      | `ERROR => <Alert kind=`Danger message="Unsynced" />
      | `SYNCED => <Alert kind=`Success message="Synced" />
      | `BOOTSTRAP => <Alert kind=`Warning message="Syncing" />
      };
    };
  };
};

[@react.component]
let make = () => {
  let url = ReasonReact.Router.useUrl();
  let onSettingsPage =
    switch (url.path) {
    | ["settings", ..._] => true
    | _ => false
    };
  <header className=Styles.header>
    <svg
      className=Css.(
        style([position(`absolute), top(`px(4)), left(`px(7))])
      )
      width="54"
      fill="transparent"
      stroke="#C4C4C4"
      height="14"
      viewBox="-1 -1 54 14"
      xmlns="http://www.w3.org/2000/svg">
      <circle cx="6" cy="6" r="6" />
      <circle cx="26" cy="6" r="6" />
      <circle cx="46" cy="6" r="6" />
    </svg>
    <div className=Styles.logo onClick={_ => ReasonReact.Router.push("/")}>
      <img src="CodaLogo.svg" alt="Coda logo" />
    </div>
    <div className=Styles.rightButtons>
      <SyncStatusQuery fetchPolicy="no-cache" partialRefetch=true>
        {response =>
           <SyncStatus
             result={response.result}
             subscribeToMore={response.subscribeToMore}
           />}
      </SyncStatusQuery>
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
