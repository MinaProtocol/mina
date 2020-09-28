type kind =
  | GetStarted
  | Developers
  | CommunityLanding
  | HelpAndSupport;

module Card = {
  module Styles = {
    open Css;
    let container =
      style([
        display(`flex),
        justifyContent(`spaceBetween),
        flexDirection(`column),
        padding2(~h=`rem(1.), ~v=`rem(0.5)),
        width(`percent(100.)),
        border(`px(1), `solid, Theme.Colors.white),
        backgroundColor(Theme.Colors.digitalBlack),
        borderTopLeftRadius(`px(4)),
        borderBottomRightRadius(`px(4)),
        borderTopRightRadius(`px(1)),
        borderBottomLeftRadius(`px(1)),
        cursor(`pointer),
        textDecoration(`none),
        fontSize(`px(12)),
        transformStyle(`preserve3d),
        transition("background", ~duration=200, ~timingFunction=`easeIn),
        color(Theme.Colors.white),
        after([
          position(`absolute),
          contentRule(""),
          top(`rem(0.25)),
          left(`rem(0.25)),
          right(`rem(-0.25)),
          bottom(`rem(-0.25)),
          borderTopLeftRadius(`px(4)),
          borderBottomRightRadius(`px(4)),
          borderTopRightRadius(`px(1)),
          borderBottomLeftRadius(`px(1)),
          border(`px(1), `solid, Theme.Colors.white),
          transform(translateZ(`px(-1))),
          transition("transform", ~duration=200, ~timingFunction=`easeIn),
        ]),
        hover([
          color(white),
          after([transform(translate(`rem(-0.25), `rem(-0.25)))]),
        ]),
      ]);
  };
  [@react.component]
  let make = (~children=?) => {
    <div className=Styles.container>
      {switch (children) {
       | Some(children) => children
       | None => React.null
       }}
    </div>;
  };
};

module ButtonBarStyles = {
  open Css;

  let background = (kind, backgroundImg) => {
    let (mobileV, tabletV, desktopV) =
      switch (kind) {
      | GetStarted => (1.5, 5.75, 2.5)
      | Developers => (1.5, 5.75, 16.)
      | CommunityLanding => (1.5, 4.25, 4.25)
      | HelpAndSupport => (1.5, 5.75, 2.5)
      };
    let (mobileH, tabletH, desktopH) =
      switch (kind) {
      | GetStarted => (1.25, 2.75, 9.5)
      | Developers => (1.25, 2.75, 9.5)
      | CommunityLanding => (1.25, 1.25, 1.25)
      | HelpAndSupport => (1.25, 2.75, 9.5)
      };
    style([
      padding2(~v=`rem(mobileV), ~h=`rem(mobileH)),
      backgroundImage(`url(backgroundImg)),
      backgroundSize(`cover),
      media(
        Theme.MediaQuery.tablet,
        [padding2(~v=`rem(tabletV), ~h=`rem(tabletH))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [padding2(~v=`rem(desktopV), ~h=`rem(desktopH))],
      ),
    ]);
  };

  let container =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceEvenly),
      selector(
        "h2",
        [marginBottom(`rem(2.)), important(color(Theme.Colors.white))],
      ),
    ]);

  let grid =
    style([
      display(`grid),
      gridTemplateColumns([
        `repeat((`autoFit, `minmax((`rem(6.5), `fr(1.))))),
      ]),
      gridGap(`rem(1.)),
    ]);

  let content =
    style([
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
      color(Theme.Colors.white),
    ]);

  let icon = style([marginLeft(`zero), paddingTop(`rem(0.5))]);
};

module CommunityLanding = {
  module Styles = {
    open Css;

    let title =
      merge([
        style([
          Theme.Typeface.monumentGrotesk,
          color(Theme.Colors.white),
          fontSize(`rem(0.75)),
          lineHeight(`rem(1.)),
          textTransform(`uppercase),
          letterSpacing(`em(0.02)),
          marginBottom(`rem(0.5)),
        ]),
      ]);
  };
  [@react.component]
  let make = () => {
    let renderCard = (kind, title) => {
      <Card>
        <div className=ButtonBarStyles.content>
          <span className=ButtonBarStyles.icon> <Icon kind /> </span>
          <h5 className=Styles.title> {React.string(title)} </h5>
        </div>
      </Card>;
    };

    <div className=ButtonBarStyles.container>
      <h2 className=Theme.Type.pageLabel>
        {React.string("All The Things")}
      </h2>
      <div className=ButtonBarStyles.grid>
        {renderCard(Icon.Twitter, "Twitter")}
        {renderCard(Icon.Forums, "Forums")}
        {renderCard(Icon.Wiki, "Wiki")}
        {renderCard(Icon.Discord, "Discord")}
        {renderCard(Icon.Telegram, "Telegram")}
        {renderCard(Icon.Facebook, "Facebook")}
        {renderCard(Icon.WeChat, "Wechat")}
      </div>
    </div>;
  };
};

module HelpAndSupport = {
  module Styles = {
    open Css;
    let content =
      merge([
        ButtonBarStyles.content,
        style([media(Theme.MediaQuery.tablet, [alignItems(`flexStart)])]),
      ]);

    let title =
      merge([
        style([
          Theme.Typeface.monumentGrotesk,
          color(Theme.Colors.white),
          fontSize(`rem(0.75)),
          lineHeight(`rem(1.)),
          textTransform(`uppercase),
          letterSpacing(`em(0.02)),
          marginBottom(`rem(0.5)),
          media(
            Theme.MediaQuery.tablet,
            [
              textTransform(`none),
              letterSpacing(`zero),
              fontSize(`rem(1.3)),
              lineHeight(`rem(1.56)),
            ],
          ),
        ]),
      ]);

    let description =
      merge([
        Theme.Type.paragraphSmall,
        style([
          display(`none),
          color(Theme.Colors.white),
          media(Theme.MediaQuery.tablet, [display(`block)]),
        ]),
      ]);

    let icon =
      merge([
        ButtonBarStyles.icon,
        style([media(Theme.MediaQuery.tablet, [marginLeft(`auto)])]),
      ]);
  };
  [@react.component]
  let make = () => {
    let renderCard = (kind, title, description) => {
      <Card>
        <div className=Styles.content>
          <span className=Styles.icon> <Icon kind /> </span>
          <h5 className=Styles.title> {React.string(title)} </h5>
          <p className=Styles.description> {React.string(description)} </p>
        </div>
      </Card>;
    };

    <div className=ButtonBarStyles.container>
      <h2 className=Theme.Type.h2> {React.string("Help & Support")} </h2>
      <div className=ButtonBarStyles.grid>
        {renderCard(
           Icon.Discord,
           "Discord",
           "Interact with other users, ask questions and get feedback.",
         )}
        {renderCard(
           Icon.Forums,
           "Forums",
           "Explore tech topics in-depth. Good for reference.",
         )}
        {renderCard(
           Icon.Github,
           "Github",
           "Work on the protocol  and contribute to Mina's codebase.",
         )}
        {renderCard(
           Icon.Wiki,
           "Wiki",
           "Resources from the O(1) Labs team and community members.",
         )}
        {renderCard(
           Icon.Email,
           "Report A Bug",
           "Share any issues with the protocol, website or anything else.",
         )}
      </div>
    </div>;
  };
};

module GetStarted = {
  module Styles = {
    open Css;
    let content =
      merge([
        ButtonBarStyles.content,
        style([media(Theme.MediaQuery.tablet, [alignItems(`flexStart)])]),
      ]);

    let title =
      merge([
        style([
          Theme.Typeface.monumentGrotesk,
          color(Theme.Colors.white),
          fontSize(`rem(0.75)),
          lineHeight(`rem(1.)),
          textTransform(`uppercase),
          letterSpacing(`em(0.02)),
          marginBottom(`rem(0.5)),
          textAlign(`center),
          paddingTop(`rem(0.5)),
          media(
            Theme.MediaQuery.tablet,
            [
              textAlign(`left),
              textTransform(`none),
              letterSpacing(`zero),
              fontSize(`rem(1.3)),
              lineHeight(`rem(1.56)),
            ],
          ),
        ]),
      ]);

    let description =
      merge([
        Theme.Type.paragraphSmall,
        style([
          display(`none),
          color(Theme.Colors.white),
          media(Theme.MediaQuery.tablet, [display(`block)]),
        ]),
      ]);

    let icon =
      merge([
        ButtonBarStyles.icon,
        style([media(Theme.MediaQuery.tablet, [marginLeft(`auto)])]),
      ]);
  };
  [@react.component]
  let make = () => {
    let renderCard = (kind, title, description) => {
      <Card>
        <div className=Styles.content>
          <span className=Styles.icon> <Icon kind /> </span>
          <h5 className=Styles.title> {React.string(title)} </h5>
          <p className=Styles.description> {React.string(description)} </p>
        </div>
      </Card>;
    };

    <div className=ButtonBarStyles.container>
      <div className=ButtonBarStyles.grid>
        {renderCard(
           Icon.NodeOperators,
           "Run a node",
           "Getting started is easier than you think.",
         )}
        {renderCard(
           Icon.Developers,
           "Build on Mina",
           "Work on the protocol  and contribute to Mina's codebase.",
         )}
        {renderCard(
           Icon.Community,
           "Join the Community",
           "Let's keep it positive and productive.",
         )}
        {renderCard(
           Icon.GrantsProgram,
           "Apply for a Grant",
           "Roll up your sleeves and help build Mina.",
         )}
      </div>
    </div>;
  };
};

[@react.component]
let make = (~kind, ~backgroundImg) => {
  <div className={ButtonBarStyles.background(kind, backgroundImg)}>
    <Wrapped>
      {switch (kind) {
       | GetStarted => <GetStarted />
       | Developers => React.null
       | CommunityLanding => <CommunityLanding />
       | HelpAndSupport => <HelpAndSupport />
       }}
    </Wrapped>
  </div>;
};
