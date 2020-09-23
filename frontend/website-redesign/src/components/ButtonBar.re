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
        height(`percent(100.)),
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

module CommunityLanding = {
  module Styles = {
    open Css;
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
          `repeat((`autoFit, `minmax((`px(103), `fr(1.))))),
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

    let icon = style([marginLeft(`zero)]);
  };
  [@react.component]
  let make = () => {
    let renderCard = (kind, title) => {
      <Card>
        <div className=Styles.content>
          <span className=Styles.icon> <Icon kind /> </span>
          <h5 className=Styles.title> {React.string(title)} </h5>
        </div>
      </Card>;
    };

    <div className=Styles.container>
      <h2 className=Theme.Type.pageLabel>
        {React.string("All The Things")}
      </h2>
      <div className=Styles.grid>
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
          `repeat((`autoFit, `minmax((`px(103), `fr(1.))))),
        ]),
        gridGap(`rem(1.)),
      ]);

    let content =
      style([
        display(`flex),
        flexDirection(`column),
        alignItems(`center),
        color(Theme.Colors.white),
        media(Theme.MediaQuery.tablet, [alignItems(`flexStart)]),
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
      style([
        marginLeft(`zero),
        media(Theme.MediaQuery.tablet, [marginLeft(`auto)]),
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

    <div className=Styles.container>
      <h2 className=Theme.Type.h2> {React.string("Help & Support")} </h2>
      <div className=Styles.grid>
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

module Styles = {
  open Css;

  let background = backgroundImg =>
    style([
      padding2(~v=`rem(1.5), ~h=`rem(1.25)),
      backgroundImage(`url(backgroundImg)),
      backgroundSize(`cover),
      media(
        Theme.MediaQuery.tablet,
        [padding2(~v=`rem(4.25), ~h=`rem(2.75))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [padding2(~v=`rem(16.), ~h=`rem(9.5))],
      ),
    ]);
};

[@react.component]
let make = (~kind, ~backgroundImg) => {
  <div className={Styles.background(backgroundImg)}>
    <Wrapped>
      {switch (kind) {
       | GetStarted => React.null
       | Developers => React.null
       | CommunityLanding => <CommunityLanding />
       | HelpAndSupport => <HelpAndSupport />
       }}
    </Wrapped>
  </div>;
};
