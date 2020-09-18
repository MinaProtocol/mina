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
        [
          justifyContent(`spaceBetween),
          flexDirection(`column),
          padding2(~v=`rem(4.), ~h=`rem(2.5)),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [padding2(~v=`rem(7.), ~h=`rem(9.5))],
      ),
    ]);
  let headerCopy =
    style([
      display(`flex),
      flexDirection(`column),
      media(
        Theme.MediaQuery.tablet,
        [flexDirection(`row), justifyContent(`spaceBetween)],
      ),
    ]);
  let header = merge([Theme.Type.h2, style([marginBottom(`rem(1.5))])]);
  let content =
    style([
      display(`flex),
      flexDirection(`column),
      marginTop(`rem(3.0)),
      media(Theme.MediaQuery.tablet, [flexDirection(`row)]),
      media(Theme.MediaQuery.desktop, [justifyContent(`spaceBetween)]),
    ]);
};

module FeaturedContent = {
  module Styles = {
    open Css;
    let container =
      style([
        media(
          Theme.MediaQuery.tablet,
          [width(`rem(21.)), marginRight(`rem(1.))],
        ),
        media(
          Theme.MediaQuery.desktop,
          [width(`rem(30.8)), marginRight(`rem(7.))],
        ),
      ]);
    let label = merge([Theme.Type.metadata, style([marginTop(`rem(1.))])]);
    let blogListImage =
      style([
        marginTop(`rem(1.)),
        width(`rem(21.)),
        height(`rem(12.)),
        marginBottom(`rem(1.)),
        media(
          Theme.MediaQuery.desktop,
          [width(`percent(100.)), height(`rem(16.1))],
        ),
      ]);
    let header = merge([Theme.Type.h5, style([marginBottom(`rem(1.))])]);
    let subhead =
      merge([Theme.Type.paragraph, style([marginBottom(`rem(1.))])]);
  };
  [@react.component]
  let make = () => {
    <div className=Styles.container>
      <Rule color=Theme.Colors.black />
      <h4 className=Styles.label>
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
      <Link text="Read More" />
    </div>;
  };
};

/** Individual content component */
type content =
  | JobOpening
  | GrantOpportunity;

module Content = {
  module Styles = {
    open Css;
    let h4 = merge([Theme.Type.metadata, style([marginTop(`rem(1.))])]);
    let h5 = merge([Theme.Type.h5, style([marginTop(`rem(1.))])]);
  };

  [@react.component]
  let make = (~title="", ~url, ~label=JobOpening) => {
    <div>
      <Rule color=Theme.Colors.black />
      <h4 className=Styles.h4>
        {switch (label) {
         | JobOpening => React.string("Job Opening / O(1) Labs")
         | GrantOpportunity => React.string("Grant Opportunity / O(1) Labs")
         }}
      </h4>
      <h5 className=Styles.h5> {React.string(title)} </h5>
      <Link text="Read More" href=url />
    </div>;
  };
};
module ContentColumn = {
  module Styles = {
    open Css;
    let container =
      style([media(Theme.MediaQuery.desktop, [width(`rem(30.8))])]);
  };
  [@react.component]
  let make = () => {
    <div className=Styles.container>
      <Content title="Protocol Infrastructure Engineer" url="/" />
      <Content title="Protocol Infrastructure Engineer" url="/" />
      <Content title="Protocol Infrastructure Engineer" url="/" />
    </div>;
  };
};

[@react.component]
let make = () => {
  <div className=Styles.container>
    <div className=Styles.headerCopy>
      <h2 className=Styles.header> {React.string("Work with Mina")} </h2>
      <Button bgColor=Theme.Colors.black width={`rem(14.6)} paddingX=1.3>
        {React.string("See All Opportunities")}
        <Icon kind=Icon.ArrowRightMedium />
      </Button>
    </div>
    <div className=Styles.content> <FeaturedContent /> <ContentColumn /> </div>
  </div>;
};
