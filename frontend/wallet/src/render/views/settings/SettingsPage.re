open ReactIntl;
open Tc;

module Styles = {
  open Css;

  let headerContainer =
    style([display(`flex), justifyContent(`spaceBetween)]);

  let versionText =
    merge([
      Theme.Text.Header.h6,
      style([
        display(`flex),
        textTransform(`uppercase),
        paddingTop(`rem(0.5)),
      ]),
    ]);

  let container =
    style([
      position(`absolute),
      top(`rem(4.)),
      left(`zero),
      right(`zero),
      bottom(`zero),
      zIndex(99),
      background(`url("bg-texture.png")),
      backgroundColor(`hex("f2f2f2")),
      padding2(~v=`rem(2.), ~h=`rem(12.)),
      borderTop(`px(1), `solid, white),
      borderLeft(`px(1), `solid, white),
      overflow(`scroll),
    ]);

  let label =
    merge([
      Theme.Text.Header.h3,
      style([
        margin2(~v=`rem(0.5), ~h=`zero),
        color(Theme.Colors.midnight),
        textTransform(`capitalize),
      ]),
    ]);

  let emptyAccountSettings =
    style([
      display(`flex),
      alignItems(`center),
      justifyContent(`center),
      padding(rem(1.)),
    ]);

  let accountSettings =
    style([
      display(`flex),
      flexDirection(`column),
      backgroundColor(`rgba((255, 255, 255, 0.8))),
      borderRadius(`px(6)),
      border(`px(1), `solid, Theme.Colors.slateAlpha(0.4)),
      width(`rem(28.)),
    ]);

  let accountItem =
    merge([
      Theme.Text.Body.regular,
      style([
        padding(`rem(1.)),
        color(Theme.Colors.midnight),
        display(`flex),
        alignItems(`center),
        borderBottom(`px(1), `solid, Theme.Colors.slateAlpha(0.25)),
        lastChild([borderBottomWidth(`zero)]),
        hover([
          backgroundColor(Theme.Colors.midnightAlpha(0.05)),
          selector("> :last-child", [color(Theme.Colors.hyperlink)]),
        ]),
      ]),
    ]);

  let accountName = style([width(`rem(12.5)), color(Theme.Colors.marine)]);

  let accountKey =
    merge([
      Theme.Text.Body.mono,
      style([color(Theme.Colors.midnightAlpha(0.7))]),
    ]);

  let accountChevron =
    style([display(`inlineFlex), color(Theme.Colors.tealAlpha(0.5))]);
};

module Version = {
  module QueryString = [%graphql
    {|
      query getVersion {
        version
      }
    |}
  ];

  module Query = ReasonApollo.CreateQuery(QueryString);

  [@react.component]
  let make = () => {
    let prettyVersion = v =>
      String.slice(v, ~from=0, ~to_=min(8, String.length(v)));

    <div className=Styles.versionText>
      <span className=Css.(style([color(Theme.Colors.slateAlpha(0.3))]))>
        <FormattedMessage id="version" defaultMessage="Version" />
        {React.string(":")}
      </span>
      <Spacer width=0.5 />
      <span className=Css.(style([color(Theme.Colors.slateAlpha(0.7))]))>
        <Query>
          {response =>
             (
               switch (response.result) {
               | Loading => "..."
               | Error((err: ReasonApolloTypes.apolloError)) => err.message
               | Data(data) =>
                 data##version
                 |> Option.map(~f=prettyVersion)
                 |> Option.withDefault(~default="Unknown")
               }
             )
             |> React.string}
        </Query>
      </span>
    </div>;
  };
};

module AccountSettingsItem = {
  [@react.component]
  let make = (~account) => {
    let keyStr = PublicKey.toString(account##publicKey);
    let route = "/settings/" ++ Js.Global.encodeURIComponent(keyStr);
    let isLocked = Option.withDefault(~default=true, account##locked);
    let (showModal, setModalOpen) = React.useState(() => false);
    <div
      className=Styles.accountItem
      onClick={_ =>
        isLocked ? setModalOpen(_ => true) : ReasonReact.Router.push(route)
      }>
      <div className=Styles.accountName>
        <AccountName pubkey=account##publicKey />
      </div>
      <span className=Styles.accountKey>
        <Pill>
          {React.string(PublicKey.prettyPrint(account##publicKey))}
        </Pill>
      </span>
      <Spacer width=5.0 />
      <span className=Styles.accountChevron>
        <Icon kind=Icon.EmptyChevronRight />
      </span>
      {showModal
         ? <UnlockModal
             account={account##publicKey}
             onClose={() => setModalOpen(_ => false)}
             onSuccess={() => {
               setModalOpen(_ => false);
               ReasonReact.Router.push(route);
             }}
           />
         : React.null}
    </div>;
  };
};

module AccountsQueryString = [%graphql
  {|
    query getWallets {
      trackedAccounts {
        locked
        publicKey @bsDecoder(fn: "Apollo.Decoders.publicKey")
      }
    }
  |}
];

module AccountsQuery = ReasonApollo.CreateQuery(AccountsQueryString);

[@react.component]
let make = () => {
  <div className=Styles.container>
    <div className=Styles.headerContainer>
      <div className=Styles.label>
        <FormattedMessage
          id="account-settings"
          defaultMessage="Account Settings"
        />
      </div>
      <Version />
    </div>
    <Spacer height=0.5 />
    <div className=Styles.accountSettings>
      <AccountsQuery fetchPolicy="network-only">
        {({result}) =>
           switch (result) {
           | Loading =>
             <div className=Styles.emptyAccountSettings> <Loader /> </div>
           | Error(_) => React.null
           | Data(data) =>
             data##trackedAccounts
             |> Array.map(~f=account => <AccountSettingsItem account />)
             |> React.array
           }}
      </AccountsQuery>
    </div>
  </div>;
};
