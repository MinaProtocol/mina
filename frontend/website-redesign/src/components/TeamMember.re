module Styles = {
  open Css;
  let memberContainer =
    style([height(`rem(17.)), width(`rem(11.)), color(orange)]);
  let image = style([width(`rem(10.)), marginBottom(`rem(1.))]);
  let name =
    merge([
      Theme.Type.h5,
      style([
        lineHeight(`rem(1.37)),
        color(black),
        important(fontSize(`px(18))),
      ]),
    ]);
  let title =
    merge([
      Theme.Type.contributorLabel,
      style([
        lineHeight(`rem(1.37)),
        color(black),
        fontSize(`px(12)),
        maxWidth(`rem(10.)),
      ]),
    ]);
  let flexRow =
    style([
      display(`flex),
      flexDirection(`row),
      justifyContent(`spaceBetween),
      width(`rem(10.)),
    ]);
};

[@react.component]
let make = (~fullName="", ~title="", ~src="") => {
  <div className=Styles.memberContainer>
    <img className=Styles.image src />
    <div className=Styles.flexRow>
      <h5 className=Styles.name> {React.string(fullName)} </h5>
      //<Icon kind=Icon.Plus />
    </div>
    <p className=Styles.title> {React.string(title)} </p>
  </div>;
};
