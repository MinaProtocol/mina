module Styles = {
  open Css;
  let memberContainer =
    style([
      height(`rem(17.)),
      width(`rem(11.)),
      color(orange),
      hover([
        display(`flex),
        flexDirection(`column),
        alignItems(`center),
        justifyContent(`center),
        transform(`scale((1.3, 1.3))),
        padding(`rem(1.)),
        backgroundColor(Theme.Colors.digitalBlack),
        selector("> div > h5", [color(white)]),
        selector("> p", [color(white)]),
      ]),
    ]);
  let image = style([width(`percent(100.)), marginBottom(`rem(1.))]);
  let name =
    merge([
      Theme.Type.h5,
      style([color(black), important(fontSize(`px(18)))]),
    ]);
  let title =
    merge([
      Theme.Type.contributorLabel,
      style([color(black), fontSize(`px(12)), maxWidth(`rem(10.))]),
    ]);
  let flexRow =
    style([
      display(`flex),
      flexDirection(`row),
      justifyContent(`spaceBetween),
      width(`percent(100.)),
    ]);
};

[@react.component]
let make = (~fullName="", ~title="", ~src="", ~switchModalState=_ => ()) => {
  <div className=Styles.memberContainer>
    <img className=Styles.image src />
    <div className=Styles.flexRow>
      <h5 className=Styles.name> {React.string(fullName)} </h5>
      <span onClick={_ => switchModalState()}> <Icon kind=Icon.Plus /> </span>
    </div>
    <p className=Styles.title> {React.string(title)} </p>
  </div>;
};
