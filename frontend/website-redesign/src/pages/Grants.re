module Styles = {
  open Css;

  let typesOfGrantsImage =
    style([
      important(backgroundSize(`cover)),
      backgroundImage(`url("/static/img/MinaSpectrumBackground.jpg")),
      width(`percent(100.)),
      height(`rem(43.)),
      display(`flex),
      justifyContent(`center),
      alignItems(`center),
      media(Theme.MediaQuery.notMobile, [height(`rem(37.5))]),
    ]);

  let typesOfGrantsOuterContainer =
    style([
      display(`flex),
      justifyContent(`center),
      alignItems(`center),
      width(`percent(100.)),
      height(`percent(100.)),
      backgroundColor(white),
      media(
        Theme.MediaQuery.notMobile,
        [alignItems(`center), height(`rem(21.))],
      ),
    ]);

  let typesOfGrantsInnerContainer =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      alignItems(`center),
      height(`percent(100.)),
      width(`percent(100.)),
      padding2(~v=`rem(2.), ~h=`zero),
      borderBottom(`px(1), `solid, Theme.Colors.digitalBlack),
      borderTop(`px(1), `solid, Theme.Colors.digitalBlack),
      media(
        Theme.MediaQuery.notMobile,
        [
          flexDirection(`row),
          height(`percent(80.)),
          width(`percent(90.)),
        ],
      ),
      selector(
        "h3",
        [width(`rem(17.)), marginRight(`rem(1.)), marginBottom(`auto)],
      ),
    ]);

  let grantRowContainer =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      alignItems(`flexStart),
      padding2(~v=`rem(6.5), ~h=`zero),
      media(
        Theme.MediaQuery.notMobile,
        [flexDirection(`row), alignItems(`center)],
      ),
    ]);

  let grantColumnContainer =
    style([
      display(`flex),
      flexDirection(`column),
      width(`rem(26.)),
      height(`percent(100.)),
      marginTop(`rem(2.)),
      media(
        Theme.MediaQuery.notMobile,
        [marginTop(`zero), marginLeft(`rem(3.))],
      ),
    ]);

  let grantRowImage =
    style([
      width(`percent(100.)),
      media(Theme.MediaQuery.notMobile, [width(`rem(35.))]),
    ]);

  let grantContainer =
    style([
      width(`rem(17.)),
      margin2(~h=`rem(1.), ~v=`rem(1.)),
      media(
        Theme.MediaQuery.notMobile,
        [flexDirection(`row), alignItems(`center)],
      ),
    ]);
};

module TypesOfGrants = {
  module TypeOfGrant = {
    [@react.component]
    let make = (~img, ~title, ~copy) => {
      <div className=Styles.grantContainer>
        <img src=img />
        <h4 className=Theme.Type.h4> {React.string(title)} </h4>
        <p className=Theme.Type.paragraph> {React.string(copy)} </p>
      </div>;
    };
  };

  [@react.component]
  let make = () => {
    <div className=Styles.typesOfGrantsImage>
      <Wrapped>
        <div className=Styles.typesOfGrantsOuterContainer>
          <div className=Styles.typesOfGrantsInnerContainer>
            <h3 className=Theme.Type.h3>
              {React.string("Types of Grants")}
            </h3>
            <TypeOfGrant
              img="static/img/TechinalGrants.png"
              title="Technical Grants"
              copy="Contribute to engineering projects like web interfaces or to protocol enhancements like stablecoins."
            />
            <TypeOfGrant
              img="static/img/CommunityGrants.png"
              title="Community Grants"
              copy="Help with community organizing or create much-needed content to better serve our members."
            />
            <TypeOfGrant
              img="static/img/SubmitYourOwnGrant.png"
              title="Submit Your Own"
              copy="Share an idea for how to improve the Mina network or build the Mina community."
            />
          </div>
        </div>
      </Wrapped>
    </div>;
  };
};

module GrantRow = {
  [@react.component]
  let make = (~img, ~title, ~copy, ~buttonCopy, ~buttonUrl) => {
    <Wrapped>
      <div className=Styles.grantRowContainer>
        <img className=Styles.grantRowImage src=img />
        <div className=Styles.grantColumnContainer>
          <h2 className=Theme.Type.h2> {React.string(title)} </h2>
          <Spacer height=1. />
          <p className=Theme.Type.paragraph> {React.string(copy)} </p>
          <Spacer height=2.5 />
          <Button href={`Internal(buttonUrl)} bgColor=Theme.Colors.orange>
            {React.string(buttonCopy)}
            <Icon kind=Icon.ArrowRightMedium />
          </Button>
        </div>
      </div>
    </Wrapped>;
  };
};

[@react.component]
let make = () => {
  <Page title="Mina Cryptocurrency Protocol" footerColor=Theme.Colors.orange>
    <div className=Nav.Styles.spacer />
    <Hero
      title=""
      header="Grants Program"
      copy={
        Some(
          "The Project Grant program is designed to encourage community members to work on projects related to developing the Coda protocol and community.",
        )
      }
      background={
        Theme.desktop: "/static/img/GrantsHero.jpg",
        Theme.tablet: "/static/img/GrantsHero.jpg",
        Theme.mobile: "/static/img/GrantsHero.jpg",
      }
    />
    <GrantRow
      img="/static/img/GrantsRow.jpg"
      title="Work on projects with us and earn Mina tokens"
      copy={js|About $2.1M USD in Coda token grants has been allocated to support these efforts prior to Coda’s mainnet launch. There will be additional Coda token grants allocated after mainnet.|js}
      buttonCopy="Learn More"
      buttonUrl="/docs"
    />
    <TypesOfGrants />
  </Page>;
};
