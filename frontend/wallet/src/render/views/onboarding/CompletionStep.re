module Styles = {
  open Css;

  let hero = {
    style([display(`flex), flexDirection(`row)]);
  };

  let fadeIn =
    keyframes([
      (0, [opacity(0.), top(`px(50))]),
      (100, [opacity(1.), top(`px(0))]),
    ]);

  let heroLeft = {
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`center),
      width(`percent(100.0)),
      maxWidth(`rem(28.0)),
      marginLeft(`px(80)),
    ]);
  };

  let header = {
    merge([Theme.Text.Header.h1]);
  };

  let heroBody = {
    merge([
      Theme.Text.Body.regularLight,
      style([maxWidth(`rem(21.5)), color(Theme.Colors.midnightBlue)]),
    ]);
  };

  let line = {
    style([
      height(`rem(17.7)),
      marginTop(`rem(5.5)),
      marginLeft(`rem(5.)),
      borderLeft(`px(4), `solid, Theme.Colors.slateAlpha(0.05)),
    ]);
  };
  let buttonRow = {
    style([display(`flex), flexDirection(`row)]);
  };
};

module Accounts = [%graphql
  {|
    query getAccounts {
      trackedAccounts {
        publicKey @bsDecoder(fn: "Apollo.Decoders.publicKey")
      }
    }
  |}
];

module AccountQuery = ReasonApollo.CreateQuery(Accounts);

module CopyKeyButton = {
  module Styles = {
    open Css;

    let container =
      style([
        display(`flex),
        justifyContent(`center),
        alignItems(`center),
        marginLeft(`rem(5.)),
        marginTop(`rem(-8.)),
      ]);
    let publicKey =
      style([
        maxWidth(`rem(10.6)),
        height(`rem(3.43)),
        color(Theme.Colors.marineAlpha(1.)),
        backgroundColor(Theme.Colors.slateAlpha(0.05)),
        borderRadius(`rem(0.25)),
      ]);
    let heading =
      merge([
        Theme.Text.Body.semiBold,
        style([
          marginTop(`rem(0.5)),
          marginBottom(`zero),
          marginLeft(`rem(1.0)),
        ]),
      ]);
    let publicKeyString =
      merge([
        Theme.Text.Body.smallCaps,
        style([
          marginLeft(`rem(1.0)),
          marginTop(`zero),
          overflow(`hidden),
          textOverflow(`ellipsis),
        ]),
      ]);
    let button =
      style([
        display(`flex),
        justifyContent(`center),
        alignItems(`center),
        color(Theme.Colors.marineAlpha(1.)),
        backgroundColor(Theme.Colors.slateAlpha(0.05)),
        height(`rem(3.43)),
        width(`rem(6.0)),
        border(`px(0), `solid, white),
        borderRadius(`rem(0.25)),
        hover([backgroundColor(Theme.Colors.marine), color(white)]),
        focus([backgroundColor(Theme.Colors.marine), color(white)]),
        active([backgroundColor(Theme.Colors.marine), color(white)]),
      ]);
  };
  [@react.component]
  let make = (~publicKey, ~onClick) => {
    <div className=Styles.container>
      <div className=Styles.publicKey>
        <p className=Styles.heading> {React.string("Public Key")} </p>
        <p className=Styles.publicKeyString> {React.string(publicKey)} </p>
      </div>
      <Spacer width=0.1 />
      <div>
        <button onClick={_ => onClick()} className=Styles.button>
          <Icon kind=Icon.Copy />
          <Spacer width=0.3 />
          <p className=Theme.Text.Body.semiBold> {React.string("copy")} </p>
        </button>
      </div>
    </div>;
  };
};

[@react.component]
let make = (~prevStep, ~closeOnboarding) => {
  <OnboardingTemplate
    heading="Your Tokens Have Been Requested"
    description={
      <p>
        {React.string(
           "You should receive testnet tokens within an hour from the faucet. Reach out to the #support channel on our Discord community if you need help troubleshooting.",
         )}
      </p>
    }
    miscLeft=
      <>
        <Spacer height=2.0 />
        <div className=OnboardingTemplate.Styles.buttonRow>
          <Button
            style=Button.HyperlinkBlue2
            label="Go Back"
            onClick={_ => prevStep()}
          />
          <Spacer width=1.5 />
          <Button
            label="Take me to My Account"
            style=Button.HyperlinkBlue3
            onClick={_ => closeOnboarding()}
          />
        </div>
      </>
  />;
};
