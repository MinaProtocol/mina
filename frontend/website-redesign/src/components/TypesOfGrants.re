module Styles = {
  open Css;
  let grantContainer =
    style([
      width(`rem(17.)),
      margin2(~h=`rem(1.), ~v=`rem(1.5)),
      media(
        Theme.MediaQuery.notMobile,
        [
          margin2(~h=`rem(1.), ~v=`zero),
          flexDirection(`row),
          alignItems(`center),
        ],
      ),
    ]);

  let typesOfGrantsImage = (backgroundImg: Theme.backgroundImage) =>
    style([
      important(backgroundSize(`cover)),
      backgroundImage(`url(backgroundImg.mobile)),
      width(`percent(100.)),
      height(`rem(43.)),
      display(`flex),
      justifyContent(`center),
      alignItems(`center),
      media(Theme.MediaQuery.notMobile, [height(`rem(37.5))]),
      media(
        Theme.MediaQuery.tablet,
        [background(`url(backgroundImg.tablet))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          padding2(~v=`zero, ~h=`rem(9.5)),
          background(`url(backgroundImg.desktop)),
        ],
      ),
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
      media(
        Theme.MediaQuery.notMobile,
        [
          flexDirection(`row),
          alignItems(`flexStart),
          height(`percent(80.)),
        ],
      ),
      selector(
        "h3",
        [width(`rem(17.)), marginRight(`rem(1.)), marginBottom(`auto)],
      ),
    ]);
};

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
  <div className=Styles.typesOfGrantsOuterContainer>
    <div className=Styles.typesOfGrantsInnerContainer>
      <h3 className=Theme.Type.h3> {React.string("Types of Grants")} </h3>
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
  </div>;
};
