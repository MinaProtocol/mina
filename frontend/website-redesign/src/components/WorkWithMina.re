module Styles = {
  open Css;
  let container =
    style([
      display(`flex),
      flexDirection(`column),
      padding2(~v=`rem(4.), ~h=`rem(1.25)),
      justifyContent(`flexStart),
      media(
        Theme.MediaQuery.tablet,
        [justifyContent(`spaceBetween), flexDirection(`column)],
      ),
      media(
        Theme.MediaQuery.desktop,
        [padding2(~v=`rem(7.), ~h=`rem(9.5))],
      ),
    ]);
  let header = merge([Theme.Type.h2, style([marginBottom(`rem(1.))])]);
  let content =
    style([
      display(`flex),
      flexDirection(`column),
      marginTop(`rem(3.0)),
      media(Theme.MediaQuery.tablet, [flexDirection(`row)]),
    ]);
};

module FeaturedContent = {
  module Styles = {
    open Css;
    let blogListImage =
      style([
        marginTop(`rem(1.)),
        width(`rem(21.)),
        height(`rem(12.)),
        marginBottom(`rem(1.)),
      ]);
    let header = merge([Theme.Type.h5, style([marginBottom(`rem(1.))])]);
    let subhead =
      merge([Theme.Type.paragraph, style([marginBottom(`rem(1.))])]);

    // contains link including icon
    let link =
      style([
        Theme.Typeface.monumentGrotesk,
        cursor(`pointer),
        color(Theme.Colors.orange),
        display(`flex),
        marginTop(`rem(1.)),
      ]);

    let readMoreText =
      style([
        marginRight(`rem(0.2)),
        cursor(`pointer),
        marginBottom(`rem(2.)),
      ]);
  };
  [@react.component]
  let make = () => {
    <div>
      <h4 className=Theme.Type.metadata>
        {React.string("Genesis Program / O(1) Labs")}
      </h4>
      <img
        src="/static/blog/BlogListModule.jpg"
        className=Styles.blogListImage
      />
      <h5 className=Styles.header>
        {React.string("Become a Genesis Member")}
      </h5>
      <p className=Theme.Type.paragraph>
        {React.string(
           "Calling all block producers, SNARK producers and community leaders. We're looking for 1,000 participants to join the Genesis token program and form the backbone of Mina's decentralized network.",
         )}
      </p>
      <Next.Link href="/">
        <div className=Styles.link>
          <span className=Styles.readMoreText>
            {React.string("Read More")}
          </span>
          <Icon kind=Icon.ArrowRightMedium />
        </div>
      </Next.Link>
    </div>;
  };
};
module ContentColumn = {
  [@react.component]
  let make = () => {
    <div> <Rule color=Theme.Colors.digitalBlack /> </div>;
  };
};

[@react.component]
let make = () => {
  <div className=Styles.container>
    <>
      <h2 className=Styles.header> {React.string("Work with Mina")} </h2>
      <Button bgColor=Theme.Colors.black>
        {React.string("See All Opportunities")}
        <Icon kind=Icon.ArrowRightMedium />
      </Button>
    </>
    <div className=Styles.content> <FeaturedContent /> <ContentColumn /> </div>
  </div>;
};
